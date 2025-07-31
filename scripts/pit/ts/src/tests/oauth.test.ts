import { BaseTest, type TestConfig } from './baseTest.js';
import { logger } from '../utils/logger.js';

export class OauthTest extends BaseTest {
  constructor(config: TestConfig) {
    super(config);
  }

  override async runTest(): Promise<boolean> {
    return super.runTest(async () => {
      logger.info(`Executing OauthTest class from oauth.test.ts`);
      await this.testOauthFlow();
    });
  }

  private async testOauthFlow(): Promise<void> {
    if (!this.page) {
      throw new Error('Page not initialized');
    }

    // Navigate to the application (should redirect to login)
    await this.goto('/');

    // Wait for redirect to login page
    await this.page.waitForURL('http://localhost:8080/login');
    
    // Click on Google OAuth login
    await this.page.getByRole('link', { name: 'Login with Google' }).click();
    
    // Fill in test email (this will likely fail in real OAuth but tests the flow)
    await this.page.locator('input[type=email]').fill('aaa');
    await this.page.getByRole('button').nth(2).click();
    
    logger.info('✓ OAuth flow initiated successfully');
  }
}

export async function runOauthTest(config: TestConfig): Promise<boolean> {
  const test = new OauthTest(config);
  return await test.runTest();
}
