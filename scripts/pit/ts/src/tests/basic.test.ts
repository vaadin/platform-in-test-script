import { BaseTest, TestConfig } from './baseTest.js';
import { logger } from '../utils/logger.js';

export class BasicTest extends BaseTest {
  constructor(config: TestConfig) {
    super(config);
  }

  override async runTest(): Promise<boolean> {
    return super.runTest(async () => {
      logger.info(`Executing BasicTest class from basic.test.ts`);
      await this.testBasicApplication();
    });
  }

  private async testBasicApplication(): Promise<void> {
    if (!this.page) {
      throw new Error('Page not initialized');
    }

    // Navigate to the main page
    await this.goto('/');

    // Click on the "Empty (Java)" template - using nth(1) to match original
    await this.page.locator('text=Empty (Java) >> slot').nth(1).click({ timeout: 60000 });

    // Navigate to the empty-view page
    await this.goto('/empty-view');

    logger.success('Basic application test completed successfully');
  }
}

// Function to run the test (matching the original standalone script pattern)
export async function runBasicTest(config: TestConfig): Promise<boolean> {
  const test = new BasicTest(config);
  return await test.runTest();
}
