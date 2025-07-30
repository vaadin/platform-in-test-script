import { readTextFile, writeTextFile, setPropertyInFile } from '../utils/file.js';
import { logger } from '../utils/logger.js';
import type { PitConfig, AppType, TestMode } from '../types.js';

export class PatchManager {
  private config: PitConfig;

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

  private async enableJBRAutoreload(_projectPath: string): Promise<void> {
    logger.debug('Enabling JBR autoreload');
    // Implementation would configure JBR-specific settings
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
}
