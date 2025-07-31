import type { PitConfig, TestResult } from '../types.js';
import { logger } from '../utils/logger.js';
import { runCommand } from '../utils/system.js';
import { joinPaths, fileExists } from '../utils/file.js';
import { ValidationRunner, type ValidationMode } from './validationRunner.js';

export class StarterRunner {
  private readonly config: PitConfig;
  private readonly validationRunner: ValidationRunner;

  constructor(config: PitConfig) {
    this.config = config;
    this.validationRunner = new ValidationRunner(config);
  }

  async run(starterName: string, tempDir: string): Promise<TestResult> {
    const startTime = Date.now();
    
    try {
      logger.info(`Running starter: ${starterName}`);

      if (this.config.test) {
        logger.info(`Would run starter ${starterName} in ${tempDir}`);
        return {
          name: starterName,
          success: true,
          duration: Date.now() - startTime,
        };
      }

      // Create folder name (replace underscores with dashes like bash version)
      const folderName = starterName.replace(/_/g, '-');
      const projectDir = joinPaths(tempDir, folderName);

      // Check if project already exists and we're in offline mode
      if (this.config.offline && await fileExists(projectDir)) {
        logger.info(`Using existing project in offline mode: ${projectDir}`);
      } else {
        // Clean up existing project if it exists
        if (await fileExists(projectDir)) {
          logger.info(`Cleaning project folder ${projectDir}`);
          await runCommand(`rm -rf "${projectDir}"`, { cwd: tempDir });
        }

        // Generate the starter project
        await this.generateStarter(starterName, tempDir, folderName);
      }

      // Build and test the project
      await this.buildAndTestProject(projectDir, starterName);

      return {
        name: starterName,
        success: true,
        duration: Date.now() - startTime,
      };

    } catch (error) {
      return {
        name: starterName,
        success: false,
        error: error instanceof Error ? error.message : String(error),
        duration: Date.now() - startTime,
      };
    }
  }

  private async generateStarter(starterName: string, tempDir: string, folderName: string): Promise<void> {
    logger.info(`Generating starter: ${starterName}`);

    // Change to temp directory for generation
    process.chdir(tempDir);

    if (starterName.startsWith('archetype-') || starterName === 'vaadin-quarkus' || starterName.includes('hilla-') && starterName.includes('-cli')) {
      await this.generateFromArchetype(starterName, folderName);
    } else if (starterName.startsWith('initializer-')) {
      await this.generateFromInitializer(starterName, folderName);
    } else {
      await this.downloadStarter(starterName, folderName);
    }
  }

  private async generateFromArchetype(starterName: string, folderName: string): Promise<void> {
    let command: string;
    
    if (starterName.endsWith('spring')) {
      command = `mvn -ntp -q -B archetype:generate -DarchetypeGroupId=com.vaadin -DarchetypeArtifactId=vaadin-archetype-spring-application -DarchetypeVersion=LATEST -DgroupId=com.vaadin.starter -DartifactId=${folderName}`;
    } else if (starterName.startsWith('archetype')) {
      command = `mvn -ntp -q -B archetype:generate -DarchetypeGroupId=com.vaadin -DarchetypeArtifactId=vaadin-archetype-application -DarchetypeVersion=LATEST -DgroupId=com.vaadin.starter -DartifactId=${folderName}`;
    } else if (starterName === 'vaadin-quarkus') {
      command = `mvn -ntp -q -B io.quarkus.platform:quarkus-maven-plugin:create -Dextensions=vaadin -DwithCodestart -DprojectGroupId=com.vaadin.starter -DprojectArtifactId=${folderName}`;
    } else if (starterName.startsWith('hilla-') && starterName.endsWith('-cli')) {
      command = `npx @hilla/cli init --react ${folderName}`;
    } else {
      throw new Error(`Unknown archetype starter: ${starterName}`);
    }
    
    const result = await runCommand(command, { showOutput: this.config.debug });
    if (!result.success) {
      throw new Error(`Failed to generate archetype: ${result.stderr}`);
    }

    // Change to the generated directory and initialize git
    process.chdir(folderName);
    await this.initGit();
  }

  private async generateFromInitializer(starterName: string, folderName: string): Promise<void> {
    // Parse initializer configuration from name
    const isMaven = starterName.includes('-maven-');
    const isGradle = starterName.includes('-gradle-');
    
    let projectType: string;
    if (isMaven) {
      projectType = 'maven-project';
    } else if (isGradle) {
      projectType = 'gradle-project';
    } else {
      throw new Error(`Unknown initializer type: ${starterName}`);
    }

    // Use Java version from environment or compute it
    const javaVersion = '17'; // Default to Java 17
    const bootVersion = '3.4.3';
    const group = 'com.vaadin.initializer';
    const dependencies = 'vaadin,devtools';
    
    const url = `https://start.spring.io/starter.zip?type=${projectType}&language=java&bootVersion=${bootVersion}&baseDir=${folderName}&groupId=${group}&artifactId=${folderName}&name=${folderName}&description=${folderName}&packageName=${group}&packaging=jar&javaVersion=${javaVersion}&dependencies=${dependencies}`;
    
    const result = await runCommand(`curl -s '${url}' --output ${folderName}.zip`, { showOutput: this.config.debug });
    if (!result.success) {
      throw new Error(`Failed to download from initializer: ${result.stderr}`);
    }

    const unzipResult = await runCommand(`unzip -q '${folderName}.zip'`, { showOutput: this.config.debug });
    if (!unzipResult.success) {
      throw new Error(`Failed to unzip initializer: ${unzipResult.stderr}`);
    }

    // Clean up zip file
    await runCommand(`rm -f "${folderName}.zip"`, { silent: true });

    // Change to the generated directory and initialize git
    process.chdir(folderName);
    await this.initGit();
  }

  private async downloadStarter(starterName: string, folderName: string): Promise<void> {
    logger.info(`Generating from start.vaadin.com: ${starterName}`);
    
    // Handle multiple presets joined with underscores
    const presets = starterName.split('_');
    const presetParams = presets.map(p => `preset=${p}`).join('&');
    
    const url = `https://start.vaadin.com/dl?${presetParams}&projectName=${starterName}`;
    const zipFile = `${starterName}.zip`;

    // Download with appropriate verbosity
    const silentFlag = this.config.verbose || this.config.debug ? '' : '-s';
    const downloadResult = await runCommand(`curl ${silentFlag} -f '${url}' -o '${zipFile}'`, { showOutput: this.config.debug });
    if (!downloadResult.success) {
      throw new Error(`Failed to download starter: ${downloadResult.stderr}`);
    }

    // Unzip the starter
    const unzipResult = await runCommand(`unzip -q '${zipFile}'`, { showOutput: this.config.debug });
    if (!unzipResult.success) {
      throw new Error(`Failed to unzip starter: ${unzipResult.stderr}`);
    }

    // Clean up zip file
    await runCommand(`rm -f "${zipFile}"`, { silent: true });

    // Change to the generated directory and initialize git
    process.chdir(folderName);
    await this.initGit();
  }

  private async initGit(): Promise<void> {
    // Check if .git directory already exists
    if (await fileExists('.git')) {
      return;
    }

    // Initialize git repository
    await runCommand('git init -q', { silent: true });
    
    // Set up git config if not already set
    const emailResult = await runCommand('git config user.email', { silent: true });
    if (!emailResult.success || !emailResult.stdout.trim()) {
      await runCommand('git config user.email "vaadin-bot@vaadin.com"', { silent: true });
    }

    const nameResult = await runCommand('git config user.name', { silent: true });
    if (!nameResult.success || !nameResult.stdout.trim()) {
      await runCommand('git config user.name "Vaadin Bot"', { silent: true });
    }

    // Disable advice about ignored files
    await runCommand('git config advice.addIgnoredFile false', { silent: true });

    // Add all files and make initial commit
    await runCommand('git add .??* * 2>/dev/null || true');
    await runCommand('git commit -q -m "First commit" -a');
  }

  private async buildAndTestProject(projectDir: string, starterName: string): Promise<void> {
    // Determine build tools and commands
    const hasPom = await fileExists(joinPaths(projectDir, 'pom.xml'));
    const hasBuild = await fileExists(joinPaths(projectDir, 'build.gradle'));

    if (!hasPom && !hasBuild) {
      throw new Error('No build file found (pom.xml or build.gradle)');
    }

    // Get test file for the starter (this will be handled by PlaywrightRunner now)
    const testFile = undefined; // Let PlaywrightRunner determine the test

    // Determine startup messages based on project type
    const devStartupMessages = 'Started .*Application|Frontend compiled|Started ServerConnector|Started Vite|Listening on:';
    const prodStartupMessages = 'Started .*Application|Started ServerConnector|Listening on:';

    // Configure validation modes
    const currentVersion = this.config.version || 'current';

    // Run current version validations (if not skipped)
    if (!this.config.skipCurrent) {
      // Dev mode validation
      if (!this.config.skipDev) {
        const devMode: ValidationMode = {
          mode: 'dev',
          version: currentVersion,
          compileCommand: this.getCleanCommand(starterName, hasPom),
          runCommand: this.getRunDevCommand(starterName, hasPom),
          checkMessage: devStartupMessages,
          testFile,
        };

        await this.validationRunner.runValidations(starterName, projectDir, devMode);
      }

      // Production mode validation
      if (!this.config.skipProd) {
        const prodMode: ValidationMode = {
          mode: 'prod',
          version: currentVersion,
          compileCommand: this.getCompileProdCommand(starterName, hasPom),
          runCommand: this.getRunProdCommand(starterName, hasPom),
          checkMessage: prodStartupMessages,
          testFile,
        };

        await this.validationRunner.runValidations(starterName, projectDir, prodMode);
      }
    }

    // Run next version validations (if version specified)
    if (this.config.version && this.config.version !== 'current') {
      // Dev mode validation for target version
      if (!this.config.skipDev) {
        const devMode: ValidationMode = {
          mode: 'dev',
          version: this.config.version,
          compileCommand: this.getCleanCommand(starterName, hasPom),
          runCommand: this.getRunDevCommand(starterName, hasPom),
          checkMessage: devStartupMessages,
          testFile,
        };

        await this.validationRunner.runValidations(starterName, projectDir, devMode);
      }

      // Production mode validation for target version
      if (!this.config.skipProd) {
        const prodMode: ValidationMode = {
          mode: 'prod',
          version: this.config.version,
          compileCommand: this.getCompileProdCommand(starterName, hasPom),
          runCommand: this.getRunProdCommand(starterName, hasPom),
          checkMessage: prodStartupMessages,
          testFile,
        };

        await this.validationRunner.runValidations(starterName, projectDir, prodMode);
      }
    }
  }

  private getCleanCommand(starterName: string, hasPom: boolean): string {
    const mvn = this.getMavenCommand();
    const gradle = this.getGradleCommand();
    
    if (starterName.includes('gradle')) {
      return `${gradle} clean`;
    }
    return hasPom ? `${mvn} -ntp -B clean` : `${gradle} clean`;
  }

  private getCompileProdCommand(starterName: string, _hasPom: boolean): string {
    const mvn = this.getMavenCommand();
    const gradle = this.getGradleCommand();
    
    if (starterName === 'archetype-hotswap' || starterName === 'archetype-jetty') {
      return `${mvn} -ntp -B clean`;
    }
    
    if (starterName.includes('gradle')) {
      return `${gradle} clean build -Dhilla.productionMode -Dvaadin.productionMode && rm -f ./build/libs/*-plain.jar`;
    }
    
    let command = `${mvn} -ntp -B -Pproduction clean package`;
    if (this.config.pnpm) {
      command += ' -Dpnpm.enable=true';
    }
    // Add deprecation flag for prod mode (matches bash implementation)
    command += ' -Dmaven.compiler.showDeprecation';
    return command;
  }

  private getRunDevCommand(starterName: string, hasPom: boolean): string {
    const mvn = this.getMavenCommand();
    const gradle = this.getGradleCommand();
    const port = this.config.port;
    
    if (starterName === 'vaadin-quarkus') {
      return `${mvn} -ntp -B quarkus:dev -Dquarkus.http.port=${port}`;
    }
    
    if (starterName.includes('initializer') && starterName.includes('maven')) {
      return `${mvn} -ntp -B spring-boot:run -Dspring-boot.run.arguments="--server.port=${port}"`;
    }
    
    if (starterName.includes('initializer') && starterName.includes('gradle')) {
      return `${gradle} bootRun --args="--server.port=${port}"`;
    }
    
    // Default case (matches bash _getRunDev default): just "mvn -ntp -B" + pnpm flag
    // Note: This relies on the pom.xml having spring-boot-maven-plugin configured for default execution
    let command = hasPom ? `${mvn} -ntp -B` : `${gradle} bootRun --args="--server.port=${port}"`;
    
    if (this.config.pnpm && hasPom) {
      command += ' -Dpnpm.enable=true';
    }
    return command;
  }

  private getRunProdCommand(starterName: string, _hasPom: boolean): string {
    const mvn = this.getMavenCommand();
    
    if (starterName === 'archetype-hotswap' || starterName === 'archetype-jetty') {
      return `${mvn} -ntp -B -Pproduction -Dvaadin.productionMode jetty:run-war`;
    }
    
    if (starterName === 'vaadin-quarkus') {
      return 'java -jar target/quarkus-app/quarkus-run.jar';
    }
    
    if (starterName.includes('gradle')) {
      return 'java -jar ./build/libs/*.jar';
    }
    
    return 'java -jar -Dvaadin.productionMode target/*.jar';
  }

  private getMavenCommand(): string {
    // Check if maven wrapper exists (matches bash computeMvn function)
    // Note: Using sync check for simplicity, could be made async if needed
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
    // Check if gradle wrapper exists (matches bash computeGradle function)
    let gradle = 'gradle';
    try {
      const fs = eval('require')('fs');
      if (fs.existsSync('./gradlew')) {
        gradle = './gradlew';
      }
    } catch {
      // Fall back to gradle if require fails
    }
    
    // Add the gradle java installations flag (matches bash implementation)
    return `${gradle} -Porg.gradle.java.installations.auto-detect=false`;
  }
}
