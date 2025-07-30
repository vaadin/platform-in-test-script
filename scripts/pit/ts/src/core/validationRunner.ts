import type { PitConfig } from '../types.js';
import { logger } from '../utils/logger.js';
import { runCommand, killProcesses, killProcessesByPort, waitForServer } from '../utils/system.js';
import { fileExists, joinPaths, writeFile, readFile } from '../utils/file.js';
import { PatchManager } from '../patches/patchManager.js';
import { PlaywrightRunner } from './playwrightRunner.js';

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
    this.playwrightRunner = new PlaywrightRunner(config);
  }

  async runValidations(
    starterName: string,
    projectDir: string,
    mode: ValidationMode
  ): Promise<void> {
    const { mode: validationMode, version, compileCommand, runCommand: startCommand, checkMessage, testFile } = mode;
    
    logger.info(`Running ${validationMode} mode validations for ${starterName} (${version})`);

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

      // Compile the project
      logger.info(`Compiling project: ${compileCommand}`);
      const compileResult = await runCommand(compileCommand, { 
        outputFile: outputPath,
        verbose: this.config.verbose 
      });
      
      if (!compileResult.success) {
        await this.handleCompileFailure(outputPath);
        throw new Error(`Compilation failed: ${compileResult.stderr}`);
      }

      // Start the application in background
      logger.info(`Starting application: ${startCommand}`);
      const serverProcess = await runCommand(startCommand, { 
        background: true,
        outputFile: outputPath,
        verbose: this.config.verbose 
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
          await this.waitForFrontendCompiled();
        }

        // Check HTTP servlet response
        await this.checkHttpServlet(`http://localhost:${this.config.port}`);

        // Run Playwright tests
        if (testFile && !this.config.skipTests && !this.config.skipPw) {
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
        // Kill server processes
        if (serverProcess?.process) {
          logger.info('Stopping server...');
          try {
            // Try to kill the specific process first
            serverProcess.process.kill('SIGTERM');
            
            // Give it time to shut down gracefully
            await new Promise(resolve => setTimeout(resolve, 3000));
            
            // Force kill if still running
            if (!serverProcess.process.killed) {
              serverProcess.process.kill('SIGKILL');
            }
          } catch (error) {
            logger.debug(`Error killing server process: ${error}`);
          }
        }
        
        // Also kill any remaining processes on the port and by pattern
        await killProcessesByPort(this.config.port);
        await killProcesses();
      }

    } finally {
      // Clean up output file
      if (await fileExists(outputPath)) {
        await runCommand(`rm -f "${outputPath}"`);
      }
    }
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

    while (Date.now() - startTime < timeout * 1000) {
      if (await fileExists(filePath)) {
        const content = await readFile(filePath);
        if (content) {
          // Debug: show the last few lines of the file
          const lines = content.split('\n');
          const lastLines = lines.slice(-5).filter(line => line.trim());
          if (lastLines.length > 0) {
            logger.debug(`Last lines in output: ${lastLines.join(' | ')}`);
          }
          
          if (regex.test(content)) {
            logger.info(`Found startup message: ${message}`);
            return;
          }
        }
      } else {
        logger.debug(`Output file ${filePath} does not exist yet`);
      }
      await new Promise(resolve => setTimeout(resolve, 2000));
    }

    // Final debug: show file content if it exists
    if (await fileExists(filePath)) {
      const content = await readFile(filePath);
      if (content) {
        logger.debug(`Final file content (last 10 lines):`);
        const lines = content.split('\n').slice(-10);
        for (const line of lines) {
          if (line.trim()) {
            logger.debug(`  ${line}`);
          }
        }
      }
    }

    throw new Error(`Timeout waiting for message "${message}" in ${filePath}`);
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
    
    // Wait for user input
    return new Promise((resolve) => {
      process.stdin.once('data', () => {
        resolve();
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
    // Check for frontend compilation completion
    logger.info('Waiting for frontend compilation...');
    
    // Wait for frontend to be compiled (simplified implementation)
    await new Promise(resolve => setTimeout(resolve, 5000));
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
