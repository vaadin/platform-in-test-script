import { BaseTest, TestConfig } from './baseTest.js';
import { logger } from '../utils/logger.js';

export class HelloTest extends BaseTest {
  constructor(config: TestConfig) {
    super(config);
  }

  override async runTest(): Promise<boolean> {
    return super.runTest(async () => {
      logger.info(`Executing HelloTest class from hello.test.ts`);
      await this.testHelloApplication();
    });
  }

  private async testHelloApplication(): Promise<void> {
    if (!this.page) {
      throw new Error('Page not initialized');
    }

    const text = 'Greet';

    // Navigate to the main page
    await this.goto('/');

    // Take initial screenshot
    await this.takeScreenshot('initial-view');

    // Click input field
    try {
      await this.page.locator('input[type="text"]').click({ timeout: 10000 });
    } catch (error) {
      // Fallback if input not found
      logger.warn(`Input field not found: ${error}`);
    }

    // Fill input field
    await this.page.locator('input[type="text"]').fill(text);

    // Click the Say hello button
    await this.page.locator('vaadin-button').click();
    await this.takeScreenshot('button-clicked');

    // Look for the text, sometimes rendered in an alert, sometimes in the dom
    let foundText: string;
    try {
      // Try to find in notification/alert first
      const notification = this.page.locator('vaadin-notification-container');
      if (await notification.count() > 0) {
        foundText = await notification.textContent() || '';
      } else {
        // Fallback to page content
        foundText = await this.page.textContent('body') || '';
      }
    } catch (error) {
      // Final fallback - log the error but continue
      logger.warn(`Error finding text in notifications: ${error}`);
      foundText = await this.page.textContent('body') || '';
    }

    if (!new RegExp(text).test(foundText)) {
      throw new Error(`Expected text '${text}' not found in page content: ${foundText}`);
    }

    logger.info(`Found '${foundText}' text in the page`);
    logger.success('Hello application test completed successfully');
  }
}

// Function to run the test (matching the original standalone script pattern)
export async function runHelloTest(config: TestConfig): Promise<boolean> {
  const test = new HelloTest(config);
  return await test.runTest();
}
