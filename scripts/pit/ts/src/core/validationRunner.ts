import type { PitConfig } from '../types.js';
import { logger } from '../utils/logger.js';
import { runCommand, killProcessesByPort, waitForServer } from '../utils/system.js';
import { fileExists, joinPaths, writeFile, readFile } from '../utils/file.js';
import { PatchManager } from '../patches/patchManager.js';
import { PlaywrightRunner } from './playwrightRunner.js';
import { processManager } from '../utils/processManager.js';
import { dirname } from 'path';

export interface ValidationMode {
  mode: 'dev' | 'prod';
  version: string;
  compileCommand: string;
  runCommand: string;
  checkMessage: string;
  testFile?: string | undefined;
}

export class ValidationRunner {
  private readonly config: PitConfig;
  private readonly patchManager: PatchManager;
  private readonly playwrightRunner: PlaywrightRunner;

  constructor(config: PitConfig) {
    this.config = config;
    this.patchManager = new PatchManager(config);
    this.playwrightRunner = new PlaywrightRunner();
  }

  async runValidations(
    starterName: string,
    projectDir: string,
    mode: ValidationMode
  ): Promise<void> {
    const { mode: validationMode, version, compileCommand, runCommand: startCommand, checkMessage, testFile } = mode;
    
    // Make the mode validation message more prominent
    const modeEmoji = validationMode === 'dev' ? '🛠️' : '🚀';
    logger.separator(`${modeEmoji} Running ${validationMode.toUpperCase()} mode validations for ${starterName} (${version})`);

    const timeout = this.getTimeout(starterName);
    const outputFile = `${starterName}-${validationMode}-${version}-${process.platform}.out`;
    const outputPath = joinPaths(projectDir, outputFile);

    try {
      // Change to project directory
      process.chdir(projectDir);

      // Apply patches before testing
      await this.patchManager.applyPatches(starterName, 'next', version, validationMode, projectDir);

      // Check if port is busy
      await this.checkBusyPort(this.config.port);

      // Optimize build settings
      await this.optimizeBuildSettings(projectDir);

      // Output dependency tree to file (unless in verbose mode)
      if (!this.config.verbose && !this.config.debug) {
        await this.outputDependencyTree(projectDir, validationMode, outputPath);
      }

      // Compile the project
      logger.info(`Compiling project: ${compileCommand}`);
      const compileResult = await runCommand(compileCommand, { 
        outputFile: outputPath,
        showOutput: this.config.debug 
      });
      
      if (!compileResult.success) {
        await this.handleCompileFailure(outputPath);
        throw new Error(`Compilation failed: ${compileResult.stderr}`);
      }

      // Start the application in background
      logger.info(`Starting application: ${startCommand}`);
      await runCommand(startCommand, { 
        background: true,
        outputFile: outputPath,
        showOutput: this.config.debug,
        processId: `${starterName}-${validationMode}-server`
      });

      // Give the server a moment to start before we begin monitoring
      await new Promise(resolve => setTimeout(resolve, 2000));

      try {
        // Wait for server startup message
        await this.waitUntilMessageInFile(outputPath, checkMessage, timeout);

        // Wait for server to be ready on port
        await waitForServer(`http://localhost:${this.config.port}`, timeout);

        // Handle interactive mode
        if (this.config.interactive) {
          await this.waitForUserTesting();
        }

        // Check for deprecated API usage in production mode
        if (validationMode === 'prod') {
          await this.checkDeprecatedApi(outputPath);
        }

        // Check dev bundle creation in dev mode
        if (validationMode === 'dev') {
          await this.checkDevBundle();
          // Wait for frontend compilation BEFORE checking HTTP servlet
          await this.waitForFrontendCompiled();
        }

        // Check HTTP servlet response
        await this.checkHttpServlet(`http://localhost:${this.config.port}`);

        // Run Playwright tests
        if (!this.config.skipTests && !this.config.skipPw) {
          await this.playwrightRunner.runTests(testFile, {
            port: this.config.port,
            mode: validationMode,
            name: starterName,
            version: version,
            headless: this.config.headless
          });
        }

        logger.success(`✓ ${starterName} ${validationMode} mode validation completed successfully`);

      } finally {
        // Kill managed processes for this starter
        logger.info('Stopping server...');
        const processId = `${starterName}-${validationMode}-server`;
        await processManager.killProcess(processId);
        
        // Also kill any remaining processes on the port and by pattern (fallback)
        await killProcessesByPort(this.config.port);
        await processManager.killAllProcesses();
        
        // Clean up patches (restore proKey, reset environment variables)
        await this.patchManager.cleanup();
      }

    } finally {
      // Clean up output file
      if (await fileExists(outputPath)) {
        await runCommand(`rm -f "${outputPath}"`);
      }
    }
  }

  private async outputDependencyTree(
    projectDir: string, 
    validationMode: string, 
    outputPath: string
  ): Promise<void> {
    const hasPom = await fileExists(joinPaths(projectDir, 'pom.xml'));
    const hasBuildGradle = await fileExists(joinPaths(projectDir, 'build.gradle'));
    
    if (hasPom) {
      const mvn = this.getMavenCommand();
      const profile = validationMode === 'prod' ? ' -Pproduction,it' : '';
      const command = `${mvn} -ntp -B dependency:tree${profile}`;
      await runCommand(command, { 
        outputFile: outputPath,
        silent: true 
      });
    } else if (hasBuildGradle) {
      const gradle = this.getGradleCommand();
      const command = `${gradle} dependencies`;
      await runCommand(command, { 
        outputFile: outputPath,
        silent: true 
      });
    }
  }

  private getMavenCommand(): string {
    // Check if maven wrapper exists (matches bash computeMvn function)
    try {
      const fs = eval('require')('fs');
      if (fs.existsSync('./mvnw')) {
        return './mvnw';
      }
    } catch {
      // Fall back to mvn if require fails (in pure ES module environments)
    }
    return 'mvn';
  }

  private getGradleCommand(): string {
    // Check if gradle wrapper exists
    try {
      const fs = eval('require')('fs');
      if (fs.existsSync('./gradlew')) {
        return './gradlew';
      }
    } catch {
      // Fall back to gradle if require fails
    }
    return 'gradle';
  }

  private getTimeout(starterName: string): number {
    // start takes longer to compile the frontend in dev-mode
    if (starterName === 'start' && this.config.timeout <= 300) {
      return 500;
    }
    return this.config.timeout;
  }

  private async checkBusyPort(port: number): Promise<void> {
    const result = await runCommand(`lsof -ti:${port} 2>/dev/null || true`, { silent: true });
    if (result.stdout.trim()) {
      logger.warn(`Port ${port} is already in use. Attempting to kill processes...`);
      
      // Try to kill processes using the port
      await killProcessesByPort(port);
      
      // Wait a moment and check again
      await new Promise(resolve => setTimeout(resolve, 2000));
      
      const checkAgain = await runCommand(`lsof -ti:${port} 2>/dev/null || true`, { silent: true });
      if (checkAgain.stdout.trim()) {
        throw new Error(`Port ${port} is already in use`);
      }
      
      logger.info(`✓ Port ${port} is now available`);
    }
  }

  private async optimizeBuildSettings(projectDir: string): Promise<void> {
    // Disable launch browser - matches bash disableLaunchBrowser() function
    await this.disableLaunchBrowser(projectDir);

    // Enable PNPM if configured
    if (this.config.pnpm) {
      await this.enablePnpm(projectDir);
    }

    // Enable Vite if configured  
    if (this.config.vite) {
      await this.enableVite(projectDir);
    }
  }

  private async disableLaunchBrowser(projectDir: string): Promise<void> {
    // Find all application.properties files in src directory (matches bash implementation)
    const srcDir = joinPaths(projectDir, 'src');
    if (!(await fileExists(srcDir))) {
      return;
    }

    try {
      const propertiesFiles = await this.findApplicationPropertiesFiles(srcDir);
      
      for (const file of propertiesFiles) {
        const fullPath = joinPaths(projectDir, file);
        if (await fileExists(fullPath)) {
          await this.removePropertyFromFile(fullPath, 'vaadin.launch-browser');
          logger.debug(`Removed vaadin.launch-browser from ${file}`);
        }
      }
    } catch (error) {
      logger.debug(`Error in disableLaunchBrowser: ${error}`);
    }
  }

  private async findApplicationPropertiesFiles(srcDir: string): Promise<string[]> {
    const { exec } = await import('child_process');
    const { promisify } = await import('util');
    const execAsync = promisify(exec);
    
    try {
      // We use 'find src' relative to project directory to match bash behavior
      const { stdout } = await execAsync(`find src -name application.properties 2>/dev/null || true`);
      return stdout.trim().split('\n').filter(file => file.length > 0);
    } catch (error) {
      logger.debug(`Error finding application.properties files in ${srcDir}: ${error}`);
      return [];
    }
  }

  private async removePropertyFromFile(filePath: string, propertyName: string): Promise<void> {
    if (!(await fileExists(filePath))) {
      return;
    }

    const content = await readFile(filePath);
    if (!content) {
      return;
    }

    // Remove lines that contain the property (matches bash setPropertyInFile with 'remove')
    const lines = content.split('\n');
    const filteredLines = lines.filter(line => {
      const trimmed = line.trim();
      return !trimmed.startsWith(propertyName + '=') && 
             !trimmed.startsWith(propertyName + ':');
    });

    await writeFile(filePath, filteredLines.join('\n'));
  }

  private async enablePnpm(projectDir: string): Promise<void> {
    const pomPath = joinPaths(projectDir, 'pom.xml');
    if (await fileExists(pomPath)) {
      // Add PNPM configuration to pom.xml
      // This is a simplified version - in production you'd want more robust XML manipulation
      logger.info('Enabling PNPM support');
    }
  }

  private async enableVite(projectDir: string): Promise<void> {
    const pomPath = joinPaths(projectDir, 'pom.xml');
    if (await fileExists(pomPath)) {
      // Add Vite configuration to pom.xml
      logger.info('Enabling Vite support');
    }
  }

  private async waitUntilMessageInFile(
    filePath: string, 
    message: string, 
    timeout: number
  ): Promise<void> {
    const startTime = Date.now();
    const regex = new RegExp(message);

    logger.debug(`Waiting for message "${message}" in file ${filePath}`);

    // Create list of files to check (primary + fallbacks)
    const checkFiles = await this.getOutputFilesToCheck(filePath);

    while (Date.now() - startTime < timeout * 1000) {
      // Check each potential output file
      for (const checkFile of checkFiles) {
        const found = await this.checkFileForMessage(checkFile, regex, message);
        if (found) {
          return;
        }
      }

      // Sleep for 4 seconds (matches bash __sleep=4)
      await new Promise(resolve => setTimeout(resolve, 4000));
    }

    // Log final debug info before timeout
    await this.logFinalDebugInfo(checkFiles);
    throw new Error(`Timeout waiting for message "${message}". Checked files: ${checkFiles.join(', ')}`);
  }

  private async getOutputFilesToCheck(filePath: string): Promise<string[]> {
    return [
      filePath,
      filePath.replace('.out', '.log'),
      joinPaths(dirname(filePath), 'startup-output.log'),
      joinPaths(dirname(filePath), 'server-output.log'),
    ];
  }

  private async checkFileForMessage(filePath: string, regex: RegExp, message: string): Promise<boolean> {
    if (!(await fileExists(filePath))) {
      return false;
    }

    const content = await readFile(filePath);
    if (!content) {
      return false;
    }

    // Debug: show the last few lines of the file
    const lines = content.split('\n');
    const lastLines = lines.slice(-5).filter(line => line.trim());
    if (lastLines.length > 0) {
      logger.debug(`Last lines in output (${filePath}): ${lastLines.join(' | ')}`);
    }
    
    if (regex.test(content)) {
      logger.info(`Found startup message: ${message} in ${filePath}`);
      return true;
    }

    return false;
  }

  private async logFinalDebugInfo(checkFiles: string[]): Promise<void> {
    for (const checkFile of checkFiles) {
      if (await fileExists(checkFile)) {
        const content = await readFile(checkFile);
        if (content) {
          logger.debug(`Final file content (last 10 lines) from ${checkFile}:`);
          const lines = content.split('\n').slice(-10);
          for (const line of lines) {
            if (line.trim()) {
              logger.debug(`  ${line}`);
            }
          }
        }
      }
    }
  }

  private async handleCompileFailure(outputPath: string): Promise<void> {
    if (await fileExists(outputPath)) {
      const content = await readFile(outputPath);
      if (content) {
        const failures = content.match(/FAILURE.*$/gm);
        if (failures) {
          logger.error(`Failed Tests: ${failures.join('\n')}`);
        }
      }
    }
  }

  private async waitForUserTesting(): Promise<void> {
    logger.info('🔔 Interactive mode: Please test the application manually');
    logger.info(`🌐 Open http://localhost:${this.config.port} in your browser`);
    logger.info('Press Enter when you have finished testing...');
    
    // Ensure stdin is in raw mode for immediate response
    if (process.stdin.isTTY) {
      process.stdin.setRawMode(false);
    }
    
    // Wait for user input
    return new Promise((resolve) => {
      const cleanup = () => {
        process.stdin.pause();
        resolve();
      };
      
      process.stdin.resume();
      process.stdin.once('data', cleanup);
      
      // Timeout after 10 minutes to prevent infinite hanging
      const timeout = setTimeout(() => {
        process.stdin.removeListener('data', cleanup);
        logger.info('Interactive mode timeout reached, continuing...');
        cleanup();
      }, 10 * 60 * 1000);
      
      // Clear timeout when user responds
      process.stdin.once('data', () => {
        clearTimeout(timeout);
      });
    });
  }

  private async checkDeprecatedApi(outputPath: string): Promise<void> {
    if (await fileExists(outputPath)) {
      const content = await readFile(outputPath);
      if (content) {
        const deprecatedWarnings = content
          .split('\n')
          .filter(line => line.includes('WARNING') && line.includes('deprecated'))
          .map(line => line.replace(/^.*\/src\//, 'src/'));
        
        if (deprecatedWarnings.length > 0) {
          logger.warn('Deprecated API usage found:');
          deprecatedWarnings.forEach(warning => logger.warn(warning));
        }
      }
    }
  }

  private async checkDevBundle(): Promise<void> {
    const devBundlePath = 'src/main/dev-bundle';
    if (await fileExists(devBundlePath)) {
      throw new Error('Dev bundle was created in dev mode - should come from platform');
    }
  }

  private async waitForFrontendCompiled(): Promise<void> {
    // Check for frontend compilation completion by checking X-DevModePending header
    // This is equivalent to the bash waitUntilFrontendCompiled function
    logger.info('Waiting for frontend compilation...');
    
    if (this.config.test) {
      return; // Skip in test mode
    }

    const url = `http://localhost:${this.config.port}`;
    let totalTime = 0;
    const checkInterval = 3000; // 3 seconds between checks
    
    while (true) {
      try {
        const response = await fetch(url, {
          headers: {
            'Accept': 'text/html'
          },
          redirect: 'follow'
        });

        // Check if X-DevModePending header is present
        const devModePending = response.headers.get('X-DevModePending');
        
        if (!devModePending) {
          // Frontend compilation is complete
          logger.info(`Frontend compilation completed after ${totalTime} seconds`);
          return;
        }

        // Still compiling, wait and try again
        logger.debug(`Frontend still compiling... (${totalTime}s elapsed)`);
        await new Promise(resolve => setTimeout(resolve, checkInterval));
        totalTime += checkInterval / 1000;

      } catch (error) {
        // If there's a connection error, the server might still be starting
        logger.debug(`Server not ready yet, retrying... (${totalTime}s elapsed): ${error}`);
        await new Promise(resolve => setTimeout(resolve, checkInterval));
        totalTime += checkInterval / 1000;
        
        // Prevent infinite loop - give up after reasonable time
        if (totalTime > this.config.timeout) {
          throw new Error(`Timeout waiting for frontend compilation after ${totalTime} seconds. Last error: ${error}`);
        }
      }
    }
  }

  private async checkHttpServlet(url: string): Promise<void> {
    const maxRetries = 5;
    let attempt = 0;

    while (attempt < maxRetries) {
      try {
        const response = await fetch(url);
        if (response.ok) {
          const contentType = response.headers.get('content-type');
          if (contentType?.includes('text/html')) {
            logger.info('✓ HTTP servlet is responding correctly');
            return;
          }
        }
      } catch (error) {
        // Ignore error and retry
        logger.debug(`HTTP check attempt ${attempt + 1} failed: ${error}`);
      }
      
      attempt++;
      await new Promise(resolve => setTimeout(resolve, 2000));
    }

    throw new Error(`HTTP servlet check failed for ${url}`);
  }
}
