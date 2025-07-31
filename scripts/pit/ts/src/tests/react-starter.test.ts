import { BaseTest, TestConfig } from './baseTest.js';
import { logger } from '../utils/logger.js';

export class ReactStarterTest extends BaseTest {
  constructor(config: TestConfig) {
    super(config);
  }

  override async runTest(): Promise<boolean> {
    return super.runTest(async () => {
      logger.info(`Executing ReactStarterTest class from react-starter.test.ts`);
      await this.testReactStarterApplication();
    });
  }

  private async testReactStarterApplication(): Promise<void> {
    if (!this.page) {
      throw new Error('Page not initialized');
    }

    // Navigate to the main page
    await this.goto('/');

    // Test Hello functionality
    await this.page.locator('text=Hello').nth(0).click();
    await this.page.locator('input[type="text"]').fill('Greet');
    await this.page.locator('text=Say hello').click();
    await this.page.locator('text=Hello Greet');

    // Test About page
    await this.page.locator('text=About').nth(0).click();
    await this.page.locator('text=/This place/');

    logger.success('React starter application test completed successfully');
  }
}

// Function to run the test (matching the original standalone script pattern)
export async function runReactStarterTest(config: TestConfig): Promise<boolean> {
  const test = new ReactStarterTest(config);
  return await test.runTest();
}
