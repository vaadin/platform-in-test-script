import { BaseTest, TestConfig } from './baseTest.js';
import { logger } from '../utils/logger.js';
import { log, dismissDevmode } from './testUtils.js';

export class NoopTest extends BaseTest {
  constructor(config: TestConfig) {
    super(config);
  }

  override async runTest(): Promise<boolean> {
    return super.runTest(async () => {
      logger.info(`Executing NoopTest class from noop.test.ts`);
      await this.testNoopApplication();
    });
  }

  private async testNoopApplication(): Promise<void> {
    if (!this.page) {
      throw new Error('Page not initialized');
    }

    // Navigate to the main page
    await this.goto('/');

    // Wait for the outlet to be populated with content
    await this.page.waitForSelector('#outlet > * > *:not(style):not(script)');
    await this.takeScreenshot('view-loaded');

    // Dismiss dev mode if in dev mode
    if (this.config.mode === 'dev') {
      await dismissDevmode(this.page);
      await this.takeScreenshot('dismissed-dev');
    }

    // Get the HTML content of the outlet
    const txt = await this.page.locator('#outlet').first().innerHTML();
    log(txt);

    logger.success('Noop application test completed successfully');
  }
}

// Function to run the test (matching the original standalone script pattern)
export async function runNoopTest(config: TestConfig): Promise<boolean> {
  const test = new NoopTest(config);
  return await test.runTest();
}
