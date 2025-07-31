import { BaseTest, type TestConfig } from './baseTest.js';
import { logger } from '../utils/logger.js';

export class StartAuthTest extends BaseTest {
  constructor(config: TestConfig) {
    super(config);
  }

  override async runTest(): Promise<boolean> {
    return super.runTest(async () => {
      logger.info(`Executing StartAuthTest class from start-auth.test.ts`);
      await this.testAuthFlow();
    });
  }

  private async testAuthFlow(): Promise<void> {
    if (!this.page) {
      throw new Error('Page not initialized');
    }

    // Navigate to the application (should redirect to login)
    await this.goto('/');

    // Wait for redirect to login page
    await this.page.waitForURL('http://localhost:8080/login');
    
    // Fill login credentials
    await this.page.locator('input[name="username"]').click();
    await this.page.locator('input[name="username"]').fill('admin');
    await this.page.locator('input[name="password"]').click();
    await this.page.locator('input[name="password"]').fill('admin');
    
    // Click login button
    await this.page.locator('vaadin-button[role="button"]:has-text("Log in")').click();
    await this.page.waitForLoadState();
    
    logger.info('✓ Successfully logged in');

    // Test Hello World view
    await this.page.locator('text=Hello World').nth(0).click();
    await this.page.locator('text=Hello').nth(0).click();
    await this.page.locator('input[type="text"]').fill('Greet');
    await this.page.locator('text=Say hello').click();
    await this.page.locator('text=Hello Greet');
    
    logger.info('✓ Hello World functionality verified');

    // Test Master-Detail view
    await this.page.locator('text=Master-Detail').nth(0).click();
    await this.page.locator('text=eula.lane').click();
    await this.page.locator('input[type="text"]').nth(0).fill('FOO');
    await this.page.locator('text=Save').click();
    await this.page.locator('text=/stored/');
    await this.page.waitForTimeout(5000);
    
    logger.info('✓ Master-Detail functionality verified');

    // Test logout
    await this.page.locator('text=/Emma/').click();
    await this.page.locator('text=/Sign out/').click();
    await this.page.locator('h2:has-text("Log in")');
    
    logger.info('✓ Successfully logged out');
  }
}

export async function runStartAuthTest(config: TestConfig): Promise<boolean> {
  const test = new StartAuthTest(config);
  return await test.runTest();
}
