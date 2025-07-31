import { BaseTest, TestConfig } from './baseTest.js';
import { logger } from '../utils/logger.js';
import { dismissDevmode } from './testUtils.js';

export class BookstoreTest extends BaseTest {
  constructor(config: TestConfig) {
    super(config);
  }

  override async runTest(): Promise<boolean> {
    return super.runTest(async () => {
      logger.info(`Executing BookstoreTest class from bookstore.test.ts`);
      await this.testBookstoreLogin();
    });
  }

  private async testBookstoreLogin(): Promise<void> {
    if (!this.page) {
      throw new Error('Page not initialized');
    }

    // Navigate to the main page
    await this.goto('/');

    // Dismiss dev mode if present and in dev mode
    if (this.config.mode === 'dev') {
      await dismissDevmode(this.page);
    }

    // Login with admin credentials
    await this.page.getByLabel('Username').click();
    await this.page.getByLabel('Username').fill('admin');
    await this.page.getByLabel('Username').press('Tab');
    await this.page.getByLabel('Password', { exact: true }).fill('admin');
    await this.page.getByRole('button', { name: 'Log in' }).click();

    // Wait for successful login (you can uncomment and modify the commented sections for additional tests)
    
    // Note: The original test has several commented-out sections for:
    // - Creating new products
    // - Adding new categories
    // These can be uncommented and adapted as needed for specific test scenarios

    logger.success('Bookstore login test completed successfully');
  }
}

// Function to run the test (matching the original standalone script pattern)
export async function runBookstoreTest(config: TestConfig): Promise<boolean> {
  const test = new BookstoreTest(config);
  return await test.runTest();
}
