import { BaseTest, TestConfig } from './baseTest.js';
import { logger } from '../utils/logger.js';

export class StartTest extends BaseTest {
  constructor(config: TestConfig) {
    super(config);
  }

  override async runTest(): Promise<boolean> {
    return super.runTest(async () => {
      logger.info(`Executing StartTest class from start.test.ts`);
      await this.testStartApplication();
    });
  }

  private async testStartApplication(): Promise<void> {
    if (!this.page) {
      throw new Error('Page not initialized');
    }

    // Navigate to the main page
    await this.goto('/');

    // Test Hello functionality
    await this.page.locator('text=Hello').nth(0).click();
    await this.page.locator('input[type="text"]').fill('Greet');
    await this.page.locator('text=Say hello').click();
    await this.page.locator('text=Hello Greet').waitFor({ state: 'visible' });

    // Test Master-Detail functionality
    await this.page.locator('text=Master-Detail').nth(0).click();
    await this.page.locator('text=eula.lane').click();
    await this.page.locator('input[type="text"]').nth(0).fill('FOO');
    await this.page.locator('text=Save').click();
    await this.page.locator('text=/updated/').waitFor({ state: 'visible' });

    logger.success('Start application test completed successfully');
  }
}

// Function to run the test (matching the original standalone script pattern)
export async function runStartTest(config: TestConfig): Promise<boolean> {
  const test = new StartTest(config);
  return await test.runTest();
}
