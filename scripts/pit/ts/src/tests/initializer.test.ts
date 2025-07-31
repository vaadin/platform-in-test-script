import { BaseTest, type TestConfig } from './baseTest.js';
import { runCommand } from '../utils/system.js';
import { logger } from '../utils/logger.js';
import * as fs from 'fs';

export class InitializerTest extends BaseTest {
  private buildCmd: string = '';
  private buildArgs: string = '';

  constructor(config: TestConfig) {
    super(config);
    this.detectBuildTool();
  }

  private detectBuildTool(): void {
    if (fs.existsSync('mvnw')) {
      if (process.platform.startsWith('win')) {
        this.buildCmd = fs.existsSync('mvnw.bat') ? 'mvnw.bat' : 'mvnw.cmd';
      } else {
        this.buildCmd = './mvnw';
      }
      this.buildArgs = 'compiler:compile';
    } else if (fs.existsSync('gradlew')) {
      if (process.platform.startsWith('win')) {
        this.buildCmd = fs.existsSync('gradlew.bat') ? 'gradlew.bat' : 'gradlew.cmd';
      } else {
        this.buildCmd = './gradlew';
      }
      this.buildArgs = 'compileJava';
    } else {
      throw new Error('No build tool found');
    }
  }

  override async runTest(): Promise<boolean> {
    return super.runTest(async () => {
      logger.info(`Executing InitializerTest class from initializer.test.ts`);
      await this.testInitializerFlow();
    });
  }

  private async testInitializerFlow(): Promise<void> {
    if (!this.page) {
      throw new Error('Page not initialized');
    }

    // Set viewport size for consistent screenshots
    await this.page.setViewportSize({ width: 811, height: 1224 });

    // Navigate to the application
    await this.goto('/');
    await this.page.waitForTimeout(3000);
    
    logger.info('✓ Application loaded');

    if (this.config.mode === 'prod') {
      logger.info('Skipping creating views for production mode');
      const text = this.page.getByText('Could not navigate');
      const isVisible = await text.isVisible();
      if (!isVisible) {
        throw new Error('Expected "Could not navigate" text in production mode');
      }
      logger.info('✓ Production mode validation passed');
    } else {
      await this.testDevModeFlow();
    }
  }

  private async testDevModeFlow(): Promise<void> {
    if (!this.page || !this.config.starter) {
      throw new Error('Page or starter not initialized');
    }

    const isReact = /react/.test(this.config.starter);
    const linkText = isReact
      ? 'Create a view for coding the UI in TypeScript with Hilla and React'
      : 'Create a view for coding the UI in Java with Flow';
    const viewName = isReact ? '@index.tsx' : 'HomeView.java';

    logger.info(`Creating ${viewName} view using copilot`);
    await this.page.getByRole('link', { name: linkText }).click();
    await this.page.waitForTimeout(2000);
    
    await this.reloadPage();
    
    // Check if view file was created
    const findResult = await runCommand(`find src/main/frontend src/main/java -name '${viewName}'`, { silent: true });
    if (!findResult.success || !findResult.stdout.trim()) {
      throw new Error(`View file ${viewName} was not created`);
    }
    
    const viewPath = findResult.stdout.trim();
    logger.info(`✓ View file created: ${viewPath}`);

    // Compile the application so spring-devtools watches the changes
    await this.compileProject();
    
    // Wait for frontend to be built if building
    logger.info('Checking if the new view is building...');
    const building = this.page.getByText('Building');
    if (await building.isVisible()) {
      logger.info('Waiting for frontend to be built...');
      while (await building.isVisible()) {
        process.stderr.write('.');
        await this.page.waitForTimeout(1000);
      }
      console.error('');
    }

    logger.info('Checking if the new view is available');
    await this.reloadPage();
    await this.page.waitForTimeout(2000);

    const welcomeText = this.page.getByText('Welcome');
    const isWelcomeVisible = await welcomeText.isVisible();
    if (!isWelcomeVisible) {
      throw new Error('Expected "Welcome" text after view creation');
    }
    
    logger.info('✓ New view is working correctly');

    // Clean up: remove the created view
    logger.info(`Removing the view ${viewPath}`);
    if (fs.existsSync(viewPath)) {
      fs.unlinkSync(viewPath);
      logger.info('✓ View file cleaned up');
    }
  }

  private async compileProject(): Promise<void> {
    logger.info('Re-compiling project');
    const compileResult = await runCommand(`${this.buildCmd} ${this.buildArgs}`, { silent: true });
    
    if (!compileResult.success) {
      logger.warn(`Compilation failed: ${compileResult.stderr}`);
    } else {
      logger.info('✓ Compilation completed');
    }
    
    await this.page?.waitForTimeout(10000);
    await this.reloadPage();
  }

  private async reloadPage(): Promise<void> {
    if (!this.page) return;
    
    logger.info('Reloading page');
    let retries = 0;
    const maxRetries = 30;
    
    // Wait for server to be available
    while (retries < maxRetries) {
      try {
        await this.page.reload();
        await this.page.waitForLoadState('networkidle', { timeout: 5000 });
        logger.info('✓ Page reloaded successfully');
        return;
      } catch (error) {
        retries++;
        logger.debug(`Reload attempt ${retries}/${maxRetries} failed: ${error}`);
        await this.page.waitForTimeout(2000);
      }
    }
    
    throw new Error('Failed to reload page after multiple attempts');
  }
}

export async function runInitializerTest(config: TestConfig): Promise<boolean> {
  const test = new InitializerTest(config);
  return await test.runTest();
}
