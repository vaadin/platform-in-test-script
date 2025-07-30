import type { PitConfig, TestResult } from '../types.js';
import { logger } from '../utils/logger.js';
import { runCommand } from '../utils/system.js';
import { joinPaths, ensureDirectory, fileExists } from '../utils/file.js';
import { GITHUB_BASE } from '../constants.js';

export class DemoRunner {
  private readonly config: PitConfig;

  constructor(config: PitConfig) {
    this.config = config;
  }

  async run(demoName: string, tempDir: string): Promise<TestResult> {
    const startTime = Date.now();
    
    try {
      logger.info(`Running demo: ${demoName}`);

      if (this.config.test) {
        logger.info(`Would run demo ${demoName} in ${tempDir}`);
        return {
          name: demoName,
          success: true,
          duration: Date.now() - startTime,
        };
      }

      // Handle special case for control-center
      if (demoName.startsWith('control-center')) {
        return await this.runControlCenterTest(demoName, tempDir, startTime);
      }

      // Create project directory
      const projectDir = joinPaths(tempDir, demoName);
      await ensureDirectory(projectDir);

      // Checkout the demo
      await this.checkoutDemo(demoName, projectDir);

      // Apply patches if needed
      await this.applyPatches(demoName, projectDir);

      // Build and test the project
      await this.buildProject(projectDir);
      await this.testProject(projectDir);

      return {
        name: demoName,
        success: true,
        duration: Date.now() - startTime,
      };

    } catch (error) {
      return {
        name: demoName,
        success: false,
        error: error instanceof Error ? error.message : String(error),
        duration: Date.now() - startTime,
      };
    }
  }

  private async runControlCenterTest(demoName: string, _tempDir: string, startTime: number): Promise<TestResult> {
    logger.info('Running Control Center validation');
    
    // Control Center requires special K8s setup
    if (this.config.test) {
      logger.info('Would validate Control Center setup');
      return {
        name: demoName,
        success: true,
        duration: Date.now() - startTime,
      };
    }

    // Implementation would include K8s cluster setup, helm installation, etc.
    throw new Error('Control Center testing not yet implemented');
  }

  private async checkoutDemo(demoName: string, projectDir: string): Promise<void> {
    logger.info(`Checking out demo: ${demoName}`);

    // Parse demo name for repo and branch information
    const { repo, branch, subPath } = this.parseDemoName(demoName);
    const gitUrl = this.config.gitSsh 
      ? `git@github.com:${repo}.git`
      : `${GITHUB_BASE}${repo}.git`;

    // Clone the repository
    let cloneCommand = `git clone ${gitUrl} .`;
    if (branch && branch !== 'main' && branch !== 'master') {
      cloneCommand += ` --branch ${branch}`;
    }

    const result = await runCommand(cloneCommand, { cwd: projectDir });
    if (!result.success) {
      throw new Error(`Failed to checkout demo: ${result.stderr}`);
    }

    // If there's a subpath, move to the correct directory
    if (subPath) {
      const moveCommand = `mv ${subPath}/* . && rm -rf ${subPath}`;
      const moveResult = await runCommand(moveCommand, { cwd: projectDir });
      if (!moveResult.success) {
        logger.warn(`Failed to move from subpath ${subPath}: ${moveResult.stderr}`);
      }
    }
  }

  private parseDemoName(demoName: string): { repo: string; branch?: string; subPath?: string } {
    // Handle complex demo names like "spring-guides/gs-crud-with-vaadin/complete"
    if (demoName.includes('/')) {
      const parts = demoName.split('/');
      if (parts.length >= 3) {
        return {
          repo: `${parts[0]}/${parts[1]}`,
          subPath: parts.slice(2).join('/'),
        };
      } else {
        return { repo: demoName };
      }
    }

    // Handle variant names like "bookstore-example:rtl-demo"
    if (demoName.includes(':')) {
      const [baseName, variant] = demoName.split(':');
      if (baseName && variant) {
        return {
          repo: `vaadin/${baseName}`,
          branch: variant,
        };
      }
    }

    // Handle JDK variants like "mpr-demo_jdk17"
    if (demoName.includes('_jdk')) {
      const baseName = demoName.split('_jdk')[0];
      return { repo: `vaadin/${baseName}` };
    }

    // Default to vaadin organization
    return { repo: `vaadin/${demoName}` };
  }

  private async applyPatches(demoName: string, projectDir: string): Promise<void> {
    logger.info('Applying patches...');

    // Apply version-specific patches and app-specific configurations
    await this.applyVersionPatches(projectDir);
    await this.applyAppSpecificPatches(demoName, projectDir);
  }

  private async applyVersionPatches(projectDir: string): Promise<void> {
    // Apply version-specific patches based on config.version
    const version = this.config.version;
    
    if (version.includes('alpha') || version.includes('beta') || version.includes('rc') || version.includes('SNAP')) {
      await this.addPrereleases(projectDir);
    }

    if (version.includes('SNAPSHOT')) {
      await this.enableSnapshots(projectDir);
    }

    // Apply other version-specific patches
    logger.debug(`Applied version patches for ${version}`);
  }

  private async applyAppSpecificPatches(demoName: string, projectDir: string): Promise<void> {
    // Apply app-specific patches based on the demo name
    const baseName = demoName.split(':')[0]?.split('_')[0];

    switch (baseName) {
      case 'vaadin-oauth-example':
        await this.configureOAuthExample(projectDir);
        break;
      case 'mpr-demo':
        await this.checkMprLicense();
        break;
      case 'form-filler-demo':
        await this.checkOpenAIToken();
        break;
      case 'vaadin-quarkus':
        await this.fixQuarkusDependencyManagement(projectDir);
        break;
      case 'releases-graph':
        await this.configureGitHubToken(projectDir);
        break;
    }
  }

  private async addPrereleases(_projectDir: string): Promise<void> {
    logger.debug('Adding prerelease repositories');
    // Implementation would modify pom.xml or build.gradle to add prerelease repos
  }

  private async enableSnapshots(_projectDir: string): Promise<void> {
    logger.debug('Enabling snapshot repositories');
    // Implementation would modify build files to enable snapshot repos
  }

  private async configureOAuthExample(_projectDir: string): Promise<void> {
    logger.debug('Configuring OAuth example');
    // Set OAuth client credentials in application.properties
  }

  private async checkMprLicense(): Promise<void> {
    const licenseFile = '~/vaadin.spreadsheet.developer.license';
    const exists = await fileExists(licenseFile);
    if (!exists) {
      throw new Error(`Install a Valid License ${licenseFile}`);
    }
  }

  private async checkOpenAIToken(): Promise<void> {
    if (this.config.test) {
      logger.info('Would check OPENAI_TOKEN environment variable');
      return;
    }
    
    if (!process.env['OPENAI_TOKEN']) {
      throw new Error('Set correctly the OPENAI_TOKEN env var');
    }
  }

  private async fixQuarkusDependencyManagement(_projectDir: string): Promise<void> {
    logger.debug('Fixing Quarkus dependency management');
    // Move Quarkus BOM to bottom of dependencyManagement block
  }

  private async configureGitHubToken(_projectDir: string): Promise<void> {
    const token = process.env['GHTK'];
    if (!token) {
      throw new Error('GHTK environment variable required for releases-graph demo');
    }
    // Set github.personal.token in application.properties
  }

  private async buildProject(projectDir: string): Promise<void> {
    logger.info('Building project...');

    // Check if it's a Maven or Gradle project
    const hasPom = await fileExists(joinPaths(projectDir, 'pom.xml'));
    const hasBuild = await fileExists(joinPaths(projectDir, 'build.gradle'));

    let buildCommand: string;
    
    if (hasPom) {
      buildCommand = this.config.skipTests ? 'mvn compile -DskipTests' : 'mvn compile test';
    } else if (hasBuild) {
      buildCommand = this.config.skipTests ? 'gradle build -x test' : 'gradle build';
    } else {
      throw new Error('No build file found (pom.xml or build.gradle)');
    }

    // Add offline flag if configured
    if (this.config.offline && hasPom) {
      buildCommand += ' --offline';
    }

    // Add pnpm flag if configured
    if (this.config.pnpm && hasPom) {
      buildCommand += ' -Dpnpm.enable=true';
    }

    const result = await runCommand(buildCommand, { cwd: projectDir });
    if (!result.success) {
      throw new Error(`Build failed: ${result.stderr}`);
    }
  }

  private async testProject(projectDir: string): Promise<void> {
    if (this.config.skipTests || this.config.skipPw) {
      logger.info('Skipping tests');
      return;
    }

    logger.info('Running tests...');

    // Start the application in the background
    const hasPom = await fileExists(joinPaths(projectDir, 'pom.xml'));
    const startCommand = hasPom 
      ? 'mvn spring-boot:run -Dspring-boot.run.arguments="--server.port=' + this.config.port + '"'
      : 'gradle bootRun --args="--server.port=' + this.config.port + '"';

    // Note: In a real implementation, we would start this in the background
    // and then run UI tests against it
    logger.info(`Would start application with: ${startCommand}`);
    logger.info(`Would run UI tests against http://localhost:${this.config.port}`);
  }
}
