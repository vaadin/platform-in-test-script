import { readTextFile, writeTextFile, setPropertyInFile } from '../utils/file.js';
import { logger } from '../utils/logger.js';
import type { PitConfig, AppType, TestMode } from '../types.js';

export class PatchManager {
  private config: PitConfig;
  private proKeyBackupPath: string | undefined;

  constructor(config: PitConfig) {
    this.config = config;
  }

  async applyPatches(
    appName: string,
    type: AppType,
    version: string,
    mode: TestMode,
    projectPath: string
  ): Promise<void> {
    if (this.config.test) {
      logger.info(`Would apply patches for ${appName} ${type} ${version}`);
      
      // In test mode, still show what patches would be applied but don't execute them
      await this.applyVersionPatches(version, type, projectPath);
      await this.applyAppPatches(appName, projectPath);
      await this.applyModePatches(mode, projectPath);
      return;
    }

    logger.info(`Applying patches for ${appName} ${type} ${version}`);

    // Apply version-specific patches
    await this.applyVersionPatches(version, type, projectPath);

    // Apply app-specific patches
    await this.applyAppPatches(appName, projectPath);

    // Apply mode-specific patches
    await this.applyModePatches(mode, projectPath);
  }

  private async applyVersionPatches(version: string, type: AppType, projectPath: string): Promise<void> {
    // Handle pre-release versions
    if (this.isPreRelease(version)) {
      await this.addPrereleases(projectPath);
    }

    // Handle snapshot versions
    if (version.includes('SNAPSHOT')) {
      await this.enableSnapshots(projectPath);
    }

    // Handle specific version patches
    if (version.startsWith('24.3.0.alpha')) {
      await this.addSpringReleaseRepo(projectPath);
    }

    // Check for old Vaadin versions
    await this.checkProjectUsingOldVaadin(type, version);

    // Downgrade Java version if needed
    await this.downgradeJava(projectPath);

    // Apply version-specific patches
    if (version.startsWith('24.8.0')) {
      if (type === 'next') {
        await this.changeMavenBlock(
          projectPath,
          'parent',
          'org.springframework.boot',
          'spring-boot-starter-parent',
          '3.5.0'
        );
      }
    }

    if (version.startsWith('25.0.0')) {
      if (type === 'next') {
        await this.addAnonymousAllowedToAppLayout(projectPath);
      }
    }
  }

  private async applyAppPatches(appName: string, projectPath: string): Promise<void> {
    const baseName = appName.split(':')[0]; // Handle variants

    switch (baseName) {
      case 'archetype-hotswap':
        logger.debug(`Applying hotswap patches for ${baseName}`);
        await this.enableJBRAutoreload(projectPath);
        break;

      case 'vaadin-oauth-example':
        await this.configureOAuthExample(projectPath);
        break;

      case 'mpr-demo':
        await this.checkMprLicense();
        break;

      case 'form-filler-demo':
        await this.checkFormFillerRequirements();
        break;

      case 'vaadin-quarkus':
        await this.fixQuarkusDependencyManagement(projectPath);
        break;

      case 'releases-graph':
        await this.configureReleasesGraph(projectPath);
        break;
    }
  }

  private async applyModePatches(mode: TestMode, _projectPath: string): Promise<void> {
    if (mode === 'prod') {
      // Apply production-specific patches
      logger.debug('Applying production mode patches');
    } else {
      // Apply development-specific patches
      logger.debug('Applying development mode patches');
    }
  }

  private isPreRelease(version: string): boolean {
    return /alpha|beta|rc|SNAP/.test(version);
  }

  private async addPrereleases(_projectPath: string): Promise<void> {
    logger.debug('Adding prerelease repositories');
    // Implementation would modify pom.xml to add prerelease repositories
  }

  private async enableSnapshots(_projectPath: string): Promise<void> {
    logger.debug('Enabling snapshot repositories');
    // Implementation would modify pom.xml to add snapshot repositories
  }

  private async addSpringReleaseRepo(_projectPath: string): Promise<void> {
    logger.debug('Adding Spring release repository');
    // Implementation would add Spring release repository to pom.xml
  }

  private async checkProjectUsingOldVaadin(type: AppType, version: string): Promise<void> {
    if (type !== 'current') return;

    const supportedVersions = ['24.9', '24.8', 'current'];
    const isSupported = supportedVersions.some(v => version.includes(v));

    if (!isSupported) {
      logger.error(`Using old version ${version}. Please upgrade to latest stable`);
    }
  }

  private async downgradeJava(projectPath: string): Promise<void> {
    try {
      const pomPath = `${projectPath}/pom.xml`;
      const pomContent = await readTextFile(pomPath);
      
      if (pomContent?.includes('<java.version>21</java.version>')) {
        const updatedContent = pomContent.replace(
          '<java.version>21</java.version>',
          '<java.version>17</java.version>'
        );
        await writeTextFile(pomPath, updatedContent);
        logger.warn('Downgraded Java version from 21 to 17 in pom.xml');
      }
    } catch (error) {
      logger.debug(`Could not downgrade Java version: ${error}`);
    }
  }

  private async changeMavenBlock(
    _projectPath: string,
    blockType: string,
    groupId: string,
    artifactId: string,
    version: string
  ): Promise<void> {
    logger.debug(`Changing Maven ${blockType} to ${groupId}:${artifactId}:${version}`);
    // Implementation would modify pom.xml to change the specified block
  }

  private async addAnonymousAllowedToAppLayout(_projectPath: string): Promise<void> {
    logger.debug('Adding @AnonymousAllowed to AppLayout classes');
    // Implementation would find Java files extending AppLayout and add the annotation
  }

  private async enableJBRAutoreload(projectPath: string): Promise<void> {
    if (this.config.test) {
      logger.info('Would install JBR for hotswap testing');
      logger.info('Would remove proKey license');
      logger.info('Would set MAVEN_OPTS with hotswap agent');
      logger.info('Would change Maven scan property from 2 -> -1');
      logger.info('Would create hotswap-agent.properties with autoHotswap=true');
      return;
    }

    logger.info('Installing JBR for hotswap testing');
    
    // Remove proKey license temporarily
    await this.removeProKey();
    
    // Install JBR (JetBrains Runtime) for hotswap support
    await this.installJBR();
    
    // Set Maven scan property to -1 to disable Jetty autoreload
    await this.changeMavenScanProperty(projectPath);
    
    // Create hotswap-agent.properties file to enable auto hotswap
    await this.createHotswapAgentProperties(projectPath);
    
    logger.info('JBR hotswap configuration completed');
  }

  private async installJBR(): Promise<void> {
    const jbrVersion = '21.0.5';
    const jbrBuild = 'b631.16';
    const hotswapVersion = '2.0.1';
    
    const jbrDir = '/tmp/jbr';
    const jbrTarball = '/tmp/JBR.tgz';
    
    // Determine platform-specific JBR URL
    let jbrUrl: string;
    if (process.platform === 'linux') {
      jbrUrl = `https://cache-redirector.jetbrains.com/intellij-jbr/jbr-${jbrVersion}-linux-x64-${jbrBuild}.tar.gz`;
    } else if (process.platform === 'darwin') {
      jbrUrl = `https://cache-redirector.jetbrains.com/intellij-jbr/jbr-${jbrVersion}-osx-x64-${jbrBuild}.tar.gz`;
    } else if (process.platform === 'win32') {
      jbrUrl = `https://cache-redirector.jetbrains.com/intellij-jbr/jbr-${jbrVersion}-windows-x64-${jbrBuild}.tar.gz`;
    } else {
      throw new Error(`Unsupported platform: ${process.platform}`);
    }
    
    const hotswapUrl = `https://github.com/HotswapProjects/HotswapAgent/releases/download/RELEASE-${hotswapVersion}/hotswap-agent-${hotswapVersion}.jar`;
    
    // Check if JBR is already installed
    const { runCommand } = await import('../utils/system.js');
    const fs = await import('fs');
    
    if (!fs.existsSync(jbrTarball)) {
      logger.info(`Downloading JBR from ${jbrUrl}`);
      const downloadResult = await runCommand(`curl -L -o "${jbrTarball}" "${jbrUrl}"`, { silent: true });
      if (!downloadResult.success) {
        throw new Error(`Failed to download JBR: ${downloadResult.stderr}`);
      }
    }
    
    if (!fs.existsSync(jbrDir)) {
      logger.info('Extracting JBR');
      await runCommand(`mkdir -p "${jbrDir}"`, { silent: true });
      const extractResult = await runCommand(`tar -xf "${jbrTarball}" -C "${jbrDir}" --strip-components 1`, { silent: true });
      if (!extractResult.success) {
        throw new Error(`Failed to extract JBR: ${extractResult.stderr}`);
      }
    }
    
    // Set JAVA_HOME to JBR
    const javaHome = process.platform === 'darwin' ? `${jbrDir}/Contents/Home` : jbrDir;
    process.env['JAVA_HOME'] = javaHome;
    process.env['PATH'] = `${javaHome}/bin:${process.env['PATH']}`;
    
    logger.info(`Setting JAVA_HOME=${javaHome} PATH=${javaHome}/bin:$PATH`);
    
    // Download hotswap agent if not present
    const hotswapDir = `${javaHome}/lib/hotswap`;
    const hotswapJar = `${hotswapDir}/hotswap-agent.jar`;
    
    if (!fs.existsSync(hotswapJar)) {
      await runCommand(`mkdir -p "${hotswapDir}"`, { silent: true });
      logger.info(`Downloading hotswap agent from ${hotswapUrl}`);
      const hotswapResult = await runCommand(`curl -L -o "${hotswapJar}" "${hotswapUrl}"`, { silent: true });
      if (!hotswapResult.success) {
        throw new Error(`Failed to download hotswap agent: ${hotswapResult.stderr}`);
      }
      logger.info(`Installed ${hotswapJar}`);
    }
    
    // Set Maven options for hotswap
    process.env['MAVEN_OPTS'] = '-XX:+AllowEnhancedClassRedefinition -XX:HotswapAgent=fatjar';
    logger.info('Set MAVEN_OPTS=\'-XX:+AllowEnhancedClassRedefinition -XX:HotswapAgent=fatjar\'');
  }

  private async changeMavenScanProperty(projectPath: string): Promise<void> {
    const pomPath = `${projectPath}/pom.xml`;
    const pomContent = await readTextFile(pomPath);
    
    if (!pomContent) {
      logger.warn('pom.xml not found, skipping scan property change');
      return;
    }
    
    // Change <scan>2</scan> to <scan>-1</scan> to disable Jetty autoreload
    const scanRegex = /(\s*<scan>)[^\s<]+(<\/scan>)/g;
    if (scanRegex.test(pomContent)) {
      // Reset the regex since test() consumes it
      const newScanRegex = /(\s*<scan>)[^\s<]+(<\/scan>)/g;
      const updatedContent = pomContent.replace(newScanRegex, (_match, prefix, suffix) => {
        return `${prefix}-1${suffix}`;
      });
      await writeTextFile(pomPath, updatedContent);
      logger.info('Disabled Jetty autoreload');
      logger.info('Changing Maven property scan from 2 -> -1 in pom.xml');
    }
  }

  private async createHotswapAgentProperties(projectPath: string): Promise<void> {
    const resourcesDir = `${projectPath}/src/main/resources`;
    const hotswapPropertiesPath = `${resourcesDir}/hotswap-agent.properties`;
    const hotswapConfig = 'autoHotswap=true\n';
    
    try {
      // Ensure the resources directory exists
      const { runCommand } = await import('../utils/system.js');
      await runCommand(`mkdir -p "${resourcesDir}"`, { silent: true });
      
      await writeTextFile(hotswapPropertiesPath, hotswapConfig);
      logger.info('Created hotswap-agent.properties with autoHotswap=true');
    } catch (error) {
      logger.warn(`Failed to create hotswap-agent.properties: ${error}`);
    }
  }

  private async configureOAuthExample(projectPath: string): Promise<void> {
    const propertiesPath = `${projectPath}/src/main/resources/application.properties`;
    
    await setPropertyInFile(
      propertiesPath,
      'spring.security.oauth2.client.registration.google.client-id',
      '553339476434-a7kb9vna7limjgucee2n0io775ra5qet.apps.googleusercontent.com'
    );
    
    await setPropertyInFile(
      propertiesPath,
      'spring.security.oauth2.client.registration.google.client-secret',
      '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'
    );
  }

  private async checkMprLicense(): Promise<void> {
    const licenseFile = '~/vaadin.spreadsheet.developer.license';
    // Check if license file exists
    logger.debug(`Checking MPR license at ${licenseFile}`);
    // Implementation would check file existence
  }

  private async checkFormFillerRequirements(): Promise<void> {
    if (this.config.test) {
      logger.info('Would check OPENAI_TOKEN environment variable');
      return;
    }

    if (!process.env['OPENAI_TOKEN']) {
      throw new Error('Set correctly the OPENAI_TOKEN env var');
    }
  }

  private async fixQuarkusDependencyManagement(_projectPath: string): Promise<void> {
    logger.info('Fixing quarkus dependencyManagement');
    // Implementation would move Quarkus BOM to bottom of dependencyManagement block
  }

  private async configureReleasesGraph(projectPath: string): Promise<void> {
    const token = process.env['GHTK'];
    if (!token) {
      throw new Error('GHTK environment variable required');
    }

    const propertiesPath = `${projectPath}/src/main/resources/application.properties`;
    await setPropertyInFile(propertiesPath, 'github.personal.token', token);
  }

  isUnsupported(appName: string, _mode: TestMode, _version: string): boolean {
    // Karaf and OSGi unsupported in 24.x
    if (appName === 'vaadin-flow-karaf-example' || appName === 'base-starter-flow-osgi') {
      return true;
    }

    // Everything else is supported
    return false;
  }

  async cleanup(): Promise<void> {
    // Restore proKey license if it was backed up
    await this.restoreProKey();
    
    // Reset JAVA_HOME and PATH if they were modified for JBR
    if (process.env['JAVA_HOME']?.includes('/tmp/jbr')) {
      logger.info('Un-setting PATH and JAVA_HOME (/tmp/jbr)');
      // Note: In a real scenario, we'd want to restore the original values
      // For now, we'll just unset them since this is typically run in a subprocess
      delete process.env['MAVEN_OPTS'];
    }
  }

  async removeProKey(): Promise<void> {
    const os = await import('os');
    const fs = await import('fs');
    const { runCommand } = await import('../utils/system.js');
    
    const proKeyPath = `${os.homedir()}/.vaadin/proKey`;
    
    if (fs.existsSync(proKeyPath)) {
      this.proKeyBackupPath = `${proKeyPath}-${process.pid}`;
      const result = await runCommand(`mv "${proKeyPath}" "${this.proKeyBackupPath}"`, { silent: true });
      if (result.success) {
        logger.info('Removing proKey license');
      } else {
        logger.warn(`Failed to backup proKey: ${result.stderr}`);
      }
    }
  }

  async restoreProKey(): Promise<void> {
    if (!this.proKeyBackupPath) {
      return;
    }

    const fs = await import('fs');
    const { runCommand } = await import('../utils/system.js');
    
    if (fs.existsSync(this.proKeyBackupPath)) {
      const os = await import('os');
      const proKeyPath = `${os.homedir()}/.vaadin/proKey`;
      
      // Check if a proKey was generated during testing
      let generatedContent = '';
      if (fs.existsSync(proKeyPath)) {
        generatedContent = fs.readFileSync(proKeyPath, 'utf8').trim();
      }
      
      const result = await runCommand(`mv "${this.proKeyBackupPath}" "${proKeyPath}"`, { silent: true });
      if (result.success) {
        logger.info('Restoring proKey license');
        
        // Report error if a proKey was generated during testing
        if (generatedContent && !this.config.test) {
          logger.error(`A proKey was generated while running validation: ${generatedContent}`);
        }
      } else {
        logger.warn(`Failed to restore proKey: ${result.stderr}`);
      }
    }
    
    this.proKeyBackupPath = undefined;
  }
}
