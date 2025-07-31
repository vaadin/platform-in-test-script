import { BaseTest, TestConfig } from './baseTest.js';
import { logger } from '../utils/logger.js';

export class LatestJavaHtmlTest extends BaseTest {
  constructor(config: TestConfig) {
    super(config);
  }

  override async runTest(): Promise<boolean> {
    return super.runTest(async () => {
      logger.info(`Executing LatestJavaHtmlTest class from latest-javahtml.test.ts`);
      await this.testLatestJavaHtmlApplication();
    });
  }

  private async testLatestJavaHtmlApplication(): Promise<void> {
    if (!this.page) {
      throw new Error('Page not initialized');
    }

    // Navigate to the main page
    await this.goto('/');

    // Click text=Master-Detail (Javahtml) >> slot >> nth=1
    await this.page.locator('text=Master-Detail (Javahtml) >> slot').nth(1).click();
    await this.page.waitForURL(`**/master-detail-view-javahtml`);

    // Click text=Person Form (Javahtml) >> slot >> nth=1
    await this.page.locator('text=Person Form (Javahtml) >> slot').nth(1).click();
    await this.page.waitForURL(`**/person-form-view-javahtml`);

    // Click text=Address Form (Javahtml) >> slot >> nth=1
    await this.page.locator('text=Address Form (Javahtml) >> slot').nth(1).click();
    await this.page.waitForURL(`**/address-form-view-javahtml`);

    // Click text=Credit Card Form (Javahtml) >> slot >> nth=1
    await this.page.locator('text=Credit Card Form (Javahtml) >> slot').nth(1).click();
    await this.page.waitForURL(`**/credit-card-form-view-javahtml`);

    // Click text=Image Gallery (Javahtml) >> slot >> nth=1
    await this.page.locator('text=Image Gallery (Javahtml) >> slot').nth(1).click();
    await this.page.waitForURL(`**/image-list-view-javahtml`);

    // Click text=Checkout Form (Javahtml) >> slot >> nth=1
    await this.page.locator('text=Checkout Form (Javahtml) >> slot').nth(1).click();
    await this.page.waitForURL(`**/checkout-form-view-javahtml`);

    logger.success('Latest Java HTML application test completed successfully');
  }
}

// Function to run the test (matching the original standalone script pattern)
export async function runLatestJavaHtmlTest(config: TestConfig): Promise<boolean> {
  const test = new LatestJavaHtmlTest(config);
  return await test.runTest();
}
