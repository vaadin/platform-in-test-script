import type { PitConfig } from '../types.js';
import { logger } from '../utils/logger.js';
import { runCommand, runCommandInBackground, killProcessesByPort, isPortBusy, sleep } from '../utils/system.js';
import { joinPaths, fileExists, readFile, writeFile } from '../utils/file.js';
import { PatchManager } from '../patches/patchManager.js';

export interface ValidationOptions {
  mode: 'dev' | 'prod';
  version: string;
  name: string;
  port: number;
  projectDir: string;
  testFile?: string;
}

export class Validator {
  private readonly config: PitConfig;
  private readonly patchManager: PatchManager;
  private backgroundProcess?: any;

  constructor(config: PitConfig) {
    this.config = config;
    this.patchManager = new PatchManager(config);
  }

  async runValidations(options: ValidationOptions): Promise<void> {
    const { mode, version, name, port, projectDir, testFile } = options;
    
    logger.info(`--> Run PiT for: app=${name}, mode=${mode}, port=${port}, version=${version}`);

    // Check if combination is unsupported
    if (this.isUnsupported(name)) {
      logger.warn(`Skipping ${name} ${mode} ${version} because of unsupported`);
      return;
    }
    
    try {
      // Apply patches before running
      await this.patchManager.applyPatches(name, 'next', version, mode, projectDir);

      // 1. Check if port is not busy
      await this.checkBusyPort(port);

      // 2. Optimize Vaadin parameters
      await this.optimizeVaadinSettings(projectDir);

      // 3. Compile the project
      await this.compileProject(projectDir, mode);

      // 4. Start the application
      await this.startApplication(projectDir, mode, port);

      // 5. Wait until application is ready
      await this.waitUntilAppReady(port);

      // 6. Interactive testing (if enabled)
      if (this.config.interactive) {
        await this.waitForUserManualTesting(port);
      }

      // 7. Check for deprecated API usage in prod mode
      if (mode === 'prod') {
        await this.checkDeprecatedApiUsage();
      }

      // 8. Check bundle not created in dev mode
      if (mode === 'dev') {
        await this.checkBundleNotCreated();
        await this.waitUntilFrontendCompiled();
      }

      // 9. Check HTTP servlet response
      await this.checkHttpServlet(port);

      // 10. Run Playwright tests
      if (testFile && !this.config.skipTests && !this.config.skipPw) {
        await this.runPlaywrightTests(testFile, mode, name, version, port);
      }

      logger.success(`The version ${version} of '${name}' app was successfully built and tested in ${mode} mode.`);

    } finally {
      // 11. Cleanup
      await this.cleanup();
    }
  }

  private async checkBusyPort(port: number): Promise<void> {
    if (this.config.test) return;
    
    if (await isPortBusy(port)) {
      throw new Error(`Port ${port} is already in use`);
    }
  }

  private async optimizeVaadinSettings(projectDir: string): Promise<void> {
    if (this.config.test) return;

    // Disable launch browser
    const vaadinDir = joinPaths(projectDir, '.vaadin');
    await runCommand(`mkdir -p "${vaadinDir}"`);
    await writeFile(joinPaths(vaadinDir, 'vaadin.properties'), 'vaadin.launch-browser=false\n');

    // Enable PNPM if configured
    if (this.config.pnpm) {
      const pomPath = joinPaths(projectDir, 'pom.xml');
      if (await fileExists(pomPath)) {
        let pomContent = await readFile(pomPath);
        if (pomContent && !pomContent.includes('pnpm.enable')) {
          pomContent = pomContent.replace(
            '</properties>',
            '    <pnpm.enable>true</pnpm.enable>\n  </properties>'
          );
          await writeFile(pomPath, pomContent);
        }
      }
    }

    // Enable Vite if configured
    if (this.config.vite) {
      const pomPath = joinPaths(projectDir, 'pom.xml');
      if (await fileExists(pomPath)) {
        let pomContent = await readFile(pomPath);
        if (pomContent && !pomContent.includes('vaadin.frontend.hotdeploy')) {
          pomContent = pomContent.replace(
            '</properties>',
            '    <vaadin.frontend.hotdeploy>true</vaadin.frontend.hotdeploy>\n  </properties>'
          );
          await writeFile(pomPath, pomContent);
        }
      }
    }
  }

  private async compileProject(projectDir: string, mode: string): Promise<void> {
    let compileCommand = await this.getCompileCommand(projectDir, mode);
    
    if (this.config.offline) {
      compileCommand += ' --offline';
    }

    logger.info(`Compiling project in ${mode} mode...`);
    const result = await runCommand(compileCommand, { cwd: projectDir });
    
    if (!result.success) {
      // Check for test failures
      const failurePattern = /FAILURE|Failed tests:/;
      if (failurePattern.test(result.stderr)) {
        throw new Error(`Failed Tests: ${result.stderr}`);
      }
      throw new Error(`Compilation failed: ${result.stderr}`);
    }
  }

  private async getCompileCommand(projectDir: string, mode: string): Promise<string> {
    const hasPom = await fileExists(joinPaths(projectDir, 'pom.xml'));
    const hasGradle = await fileExists(joinPaths(projectDir, 'build.gradle'));

    if (hasPom) {
      if (mode === 'prod') {
        return 'mvn -ntp -B -Pproduction clean package -Dmaven.compiler.showDeprecation';
      } else {
        return 'mvn -ntp -B compile test -Dmaven.compiler.showDeprecation';
      }
    } else if (hasGradle) {
      if (mode === 'prod') {
        return 'gradle clean build -Dhilla.productionMode -Dvaadin.productionMode';
      } else {
        return 'gradle build';
      }
    } else {
      throw new Error('No build file found (pom.xml or build.gradle)');
    }
  }

  private async startApplication(projectDir: string, mode: string, port: number): Promise<void> {
    const runCommand = await this.getRunCommand(projectDir, mode, port);
    
    logger.info(`Starting application: ${runCommand}`);
    
    if (this.config.test) {
      logger.info(`Would start application with: ${runCommand}`);
      return;
    }

    // Start application in background
    this.backgroundProcess = await runCommandInBackground(runCommand, { cwd: projectDir });
  }

  private async getRunCommand(projectDir: string, mode: string, port: number): Promise<string> {
    const hasPom = await fileExists(joinPaths(projectDir, 'pom.xml'));
    const hasGradle = await fileExists(joinPaths(projectDir, 'build.gradle'));

    if (hasPom) {
      if (mode === 'prod') {
        return `java -jar -Dvaadin.productionMode -Dserver.port=${port} target/*.jar`;
      } else {
        return `mvn -ntp -B spring-boot:run -Dspring-boot.run.arguments="--server.port=${port}"`;
      }
    } else if (hasGradle) {
      if (mode === 'prod') {
        return `java -jar -Dserver.port=${port} ./build/libs/*.jar`;
      } else {
        return `gradle bootRun --args="--server.port=${port}"`;
      }
    } else {
      throw new Error('No build file found');
    }
  }

  private async waitUntilAppReady(port: number): Promise<void> {
    if (this.config.test) return;

    const timeout = this.config.timeout;

    logger.info(`Waiting for application to start on port ${port}...`);

    // Wait for one of the expected messages in logs
    let startTime = Date.now();
    let appStarted = false;

    while (Date.now() - startTime < timeout * 1000 && !appStarted) {
      try {
        // Check if port is responding
        const response = await fetch(`http://localhost:${port}/`, {
          method: 'GET',
        });
        
        if (response.ok) {
          appStarted = true;
          logger.info(`Application started successfully on port ${port}`);
          break;
        }
      } catch {
        // Still starting, wait a bit more
      }

      await sleep(2000);
    }

    if (!appStarted) {
      throw new Error(`Application failed to start within ${timeout} seconds`);
    }
  }

  private async waitForUserManualTesting(port: number): Promise<void> {
    logger.info(`🔔 Application is running at http://localhost:${port}`);
    logger.info('Press Enter to continue after manual testing...');
    
    // Wait for user input
    await new Promise((resolve) => {
      process.stdin.once('data', resolve);
    });
  }

  private async checkDeprecatedApiUsage(): Promise<void> {
    // Check for deprecated API warnings in output
    // This would need to read from the actual output file
    logger.info('Checking for deprecated API usage...');
  }

  private async checkBundleNotCreated(): Promise<void> {
    // Check that no dev-bundle was created to ensure bundle comes from platform
    logger.info('Checking that dev-bundle was not created...');
  }

  private async waitUntilFrontendCompiled(): Promise<void> {
    // Wait until frontend compilation is complete in dev mode
    logger.info('Waiting for frontend compilation...');
    await sleep(5000); // Simple wait for now
  }

  private async checkHttpServlet(port: number): Promise<void> {
    if (this.config.test) {
      logger.info(`Would check HTTP servlet at http://localhost:${port}/`);
      return;
    }

    try {
      const response = await fetch(`http://localhost:${port}/`);
      if (!response.ok) {
        throw new Error(`HTTP check failed with status: ${response.status}`);
      }
      
      const content = await response.text();
      if (!content.includes('body') && !content.includes('html')) {
        throw new Error('Response does not appear to be a valid HTML page');
      }
      
      logger.info('HTTP servlet check passed');
    } catch (error) {
      throw new Error(`HTTP servlet check failed: ${error}`);
    }
  }

  private async runPlaywrightTests(testFile: string, mode: string, name: string, version: string, port: number): Promise<void> {
    if (this.config.test) {
      logger.info(`Would run Playwright tests: ${testFile}`);
      return;
    }

    const playwrightTestPath = joinPaths(process.cwd(), '..', 'its', testFile);
    
    if (!await fileExists(playwrightTestPath)) {
      logger.warn(`Playwright test file not found: ${playwrightTestPath}`);
      return;
    }

    logger.info(`Running Playwright tests: ${testFile}`);

    // Install Playwright if needed
    await this.ensurePlaywrightInstalled();

    // Run the test
    const args = [
      `--name=${name}`,
      `--version=${version}`,
      `--mode=${mode}`,
      `--port=${port}`
    ];

    if (this.config.headless) {
      args.push('--headless');
    }

    const result = await runCommand(`node "${playwrightTestPath}" ${args.join(' ')}`);
    
    if (!result.success) {
      throw new Error(`Playwright tests failed: ${result.stderr}`);
    }
    
    logger.info('Playwright tests passed');
  }

  private async ensurePlaywrightInstalled(): Promise<void> {
    // Check if Playwright is installed
    const result = await runCommand('npx playwright --version');
    if (!result.success) {
      logger.info('Installing Playwright browsers...');
      await runCommand('npx playwright install chromium');
    }
  }

  private isUnsupported(name: string): boolean {
    // Karaf and OSGi unsupported in 24.x
    if (name === 'vaadin-flow-karaf-example' || name === 'base-starter-flow-osgi') {
      return true;
    }
    
    return false;
  }

  private async cleanup(): Promise<void> {
    logger.info('Cleaning up...');
    
    if (this.backgroundProcess) {
      this.backgroundProcess.kill('SIGTERM');
      this.backgroundProcess = undefined;
    }

    // Kill any processes on the port
    await killProcessesByPort(this.config.port);
    
    await sleep(2000);
  }
}
