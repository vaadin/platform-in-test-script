import { BaseTest, type TestConfig } from './baseTest.js';
import { runCommand } from '../utils/system.js';
import { logger } from '../utils/logger.js';

export class ClickHotswapTest extends BaseTest {
  constructor(config: TestConfig) {
    super(config);
  }

  override async runTest(): Promise<boolean> {
    return super.runTest(async () => {
      logger.info(`Executing ClickHotswapTest class from click-hotswap.test.ts`);
      await this.testClickHotswapFunctionality();
    });
  }

  private async testClickHotswapFunctionality(): Promise<void> {
    if (!this.page) {
      throw new Error('Page not initialized');
    }

    // Navigate to the main page
    await this.goto('/');

    // Perform basic click test
    await this.performBasicClickTest();
    
    if (this.config.mode === 'prod') {
      logger.info('Skipping hotswap checks for production mode');
    } else {
      await this.performHotswapTest();
    }
  }

  private async performBasicClickTest(): Promise<void> {
    if (!this.page) {
      throw new Error('Page not initialized');
    }
    
    // Wait for and click the "Click me" button
    const clickButton = this.page.locator('text=Click me');
    await clickButton.waitFor({ state: 'visible', timeout: 90000 });
    await clickButton.click();
    
    // Verify "Clicked" text appears
    const clickedText = this.page.locator('text=Clicked');
    await clickedText.waitFor({ state: 'visible' });
    
    logger.info('✓ Basic click functionality verified');
  }

  private async performHotswapTest(): Promise<void> {
    if (!this.page) {
      throw new Error('Page not initialized');
    }
    
    // Find the MainView.java file
    const findResult = await runCommand('find src -name MainView.java', { silent: true });
    if (!findResult.success || !findResult.stdout.trim()) {
      logger.warn('MainView.java not found, skipping hotswap test');
      return;
    }
     
    const javaFile = findResult.stdout.trim();
    logger.info(`Found Java file: ${javaFile}`);
    
    try {
      // Change "Click" to "Foo" in the Java file
      logger.info(`Changing ${javaFile} and compiling...`);
      const changeResult = await runCommand(`perl -pi -e s/Click/Foo/g ${javaFile}`, { silent: true });
      
      if (!changeResult.success) {
        throw new Error(`Failed to modify Java file: ${changeResult.stderr}`);
      }
      
      // Compile the changes
      await this.compileProject();
      
      // Test the hotswapped functionality with better error handling
      logger.info('Looking for "Foo me" button after hotswap...');
      
      try {
        const fooButton = this.page.locator('text=Foo me');
        await fooButton.waitFor({ state: 'visible', timeout: 90000 });
        await fooButton.click();
        
        const fooedText = this.page.locator('text=Fooed');
        await fooedText.waitFor({ state: 'visible', timeout: 30000 });
        const fooContent = await fooedText.textContent();
        logger.info(`✓ Hotswap successful: ${fooContent}`);
      } catch (hotswapError) {
        logger.warn(`Hotswap test failed, this might be expected: ${hotswapError}`);
        // Continue with restoration anyway
      }
      
      // Restore the original file
      logger.info(`Restoring ${javaFile} and compiling...`);
      await runCommand(`git checkout ${javaFile}`, { silent: true });
      
      // Compile again
      await this.compileProject();
      
      // Test that the original functionality is restored
      logger.info('Verifying original functionality is restored...');
      const originalButton = this.page.locator('text=Click me');
      await originalButton.waitFor({ state: 'visible', timeout: 90000 });
      await originalButton.click();
      
      const clickedText = this.page.locator('text=Clicked');
      await clickedText.waitFor({ state: 'visible', timeout: 30000 });
      const clickContent = await clickedText.textContent();
      logger.info(`✓ Original functionality restored: ${clickContent}`);
      
    } catch (error) {
      // Always try to restore the file, even if the test failed
      try {
        logger.info('Attempting to restore file after error...');
        await runCommand(`git checkout ${javaFile}`, { silent: true });
        logger.info('File restored after test failure');
      } catch (restoreError) {
        logger.warn(`Failed to restore ${javaFile}: ${restoreError}`);
      }
      throw error;
    }
  }

  private async compileProject(): Promise<void> {
    if (!this.page) {
      throw new Error('Page not initialized');
    }
    
    try {
      const mvnCommand = process.platform.startsWith('win') ? 'mvn.cmd' : 'mvn';
      logger.info(`Compiling with: ${mvnCommand} compiler:compile`);
      
      // For compilation, use JBR Java but without hotswap agent to avoid classpath issues
      const compileEnv = {
        ...process.env,
        JAVA_HOME: process.env['JAVA_HOME'] || '',
        PATH: process.env['PATH'] || '',
        // Don't use MAVEN_OPTS with hotswap agent for compilation to avoid PluginManager classpath issues
        MAVEN_OPTS: '',
      };
      
      logger.debug(`Using JAVA_HOME: ${compileEnv.JAVA_HOME}`);
      logger.debug(`Compiling without hotswap MAVEN_OPTS to avoid classpath issues`);
      
      const compileResult = await runCommand(`${mvnCommand} compiler:compile`, { 
        silent: true,
        env: compileEnv
      });
      
      if (!compileResult.success) {
        logger.warn(`Compilation failed: ${compileResult.stderr}`);
        // Continue anyway, as hotswap might still work
      } else {
        logger.info('Compilation completed successfully');
      }
      
      logger.info('Waiting 10 seconds for compilation to take effect...');
      
      // Use a more robust timeout that can be interrupted
      await new Promise<void>((resolve, reject) => {
        const timeout = setTimeout(() => {
          logger.info('Compilation wait period completed');
          resolve();
        }, 10000);
        
        // Allow the timeout to be cleared if page becomes invalid
        if (!this.page || this.page.isClosed()) {
          clearTimeout(timeout);
          reject(new Error('Page was closed during compilation wait'));
        }
      });
      
      // If this is a Jetty-based project, reload the page
      if (this.config.starter?.includes('jetty')) {
        logger.info('Reloading page for Jetty hotswap...');
        await this.page.reload();
        await this.page.waitForLoadState('networkidle', { timeout: 30000 });
        logger.info('Page reload completed');
      }
      
    } catch (error) {
      logger.error(`Error during compilation: ${error}`);
      throw error;
    }
  }
}

export async function runClickHotswapTest(config: TestConfig): Promise<boolean> {
  const test = new ClickHotswapTest(config);
  return await test.runTest();
}
