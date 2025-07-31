import { BaseTest, TestConfig } from './baseTest.js';
import { logger } from '../utils/logger.js';

export class ReactTest extends BaseTest {
  constructor(config: TestConfig) {
    super(config);
  }

  override async runTest(): Promise<boolean> {
    return super.runTest(async () => {
      logger.info(`Executing ReactTest class from react.test.ts`);
      await this.testReactApplication();
    });
  }

  private async testReactApplication(): Promise<void> {
    if (!this.page) {
      throw new Error('Page not initialized');
    }

    // Navigate to the main page
    await this.goto('/');

    // Click on the first task element - using nth(0) to match original
    await this.page.locator('text=Todo').nth(0).click({ timeout: 60000 });

    logger.success('React application test completed successfully');
  }
}

// Function to run the test (matching the original standalone script pattern)
export async function runReactTest(config: TestConfig): Promise<boolean> {
  const test = new ReactTest(config);
  return await test.runTest();
}
