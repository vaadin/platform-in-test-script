import { BaseTest, TestConfig } from './baseTest.js';
import { logger } from '../utils/logger.js';

export class ClickTest extends BaseTest {
  constructor(config: TestConfig) {
    super(config);
  }

  override async runTest(): Promise<boolean> {
    return super.runTest(async () => {
      logger.info(`Executing ClickTest class from click.test.ts`);
      await this.testClickApplication();
    });
  }

  private async testClickApplication(): Promise<void> {
    if (!this.page) {
      throw new Error('Page not initialized');
    }

    // Navigate to the main page
    await this.goto('/');

    // Click the "Click me" button
    await this.page.locator('text=Click me').click({ timeout: 60000 });

    // Wait for the "Clicked" text to appear
    await this.page.locator('text=Clicked').waitFor({ state: 'visible' });

    logger.success('Click application test completed successfully');
  }
}

// Function to run the test (matching the original standalone script pattern)
export async function runClickTest(config: TestConfig): Promise<boolean> {
  const test = new ClickTest(config);
  return await test.runTest();
}
