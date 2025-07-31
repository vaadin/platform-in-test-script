import { BaseTest, TestConfig } from './baseTest.js';
import { logger } from '../utils/logger.js';

export class LatestJavaTest extends BaseTest {
  constructor(config: TestConfig) {
    super(config);
  }

  override async runTest(): Promise<boolean> {
    return super.runTest(async () => {
      logger.info(`Executing LatestJavaTest class from latest-java.test.ts`);
      await this.testLatestJavaApplication();
    });
  }

  private async testLatestJavaApplication(): Promise<void> {
    if (!this.page) {
      throw new Error('Page not initialized');
    }

    // Navigate to the main page
    await this.goto('/');

    // Click text=Empty (Java) >> slot >> nth=1
    await this.page.locator('text=Empty (Java) >> slot').nth(1).click();
    await this.page.waitForURL(`**/empty-view`);

    // Click text=Hello World (Java) >> slot >> nth=1
    await this.page.locator('text=Hello World (Java) >> slot').nth(1).click();
    await this.page.waitForURL(`**/hello-world-view`);

    // Click text=Dashboard (Java) >> slot >> nth=1
    await this.page.locator('text=Dashboard (Java) >> slot').nth(1).click();
    await this.page.waitForURL(`**/dashboard-view`);

    // Click text=Feed (Java) >> slot >> nth=1
    await this.page.locator('text=Feed (Java) >> slot').nth(1).click();
    await this.page.waitForURL(`**/card-list-view`);

    // Click text=Data Grid (Java) >> slot >> nth=1
    await this.page.locator('text=Data Grid (Java) >> slot').nth(1).click();
    await this.page.waitForURL(`**/list-view`);

    // Click text=Master-Detail (Java) >> slot >> nth=1
    await this.page.locator('text=Master-Detail (Java) >> slot').nth(1).click();
    await this.page.waitForURL(`**/master-detail-view`);

    // Click text=Person Form (Java) >> slot >> nth=1
    await this.page.locator('text=Person Form (Java) >> slot').nth(1).click();
    await this.page.waitForURL(`**/person-form-view`);

    // Click text=Address Form (Java) >> slot >> nth=1
    await this.page.locator('text=Address Form (Java) >> slot').nth(1).click();
    await this.page.waitForURL(`**/address-form-view`);

    // Click text=Credit Card Form (Java) >> slot >> nth=1
    await this.page.locator('text=Credit Card Form (Java) >> slot').nth(1).click();
    await this.page.waitForURL(`**/credit-card-form-view`);

    // Click text=Map (Java) >> slot >> nth=1
    await this.page.locator('text=Map (Java) >> slot').nth(1).click();
    await this.page.waitForURL(`**/map-view`);

    // Click text=Spreadsheet (Java) >> slot >> nth=1
    await this.page.locator('text=Spreadsheet (Java) >> slot').nth(1).click();
    await this.page.waitForURL(`**/spreadsheet-view`);

    // Click text=Page Editor (Java) >> slot >> nth=1
    await this.page.locator('text=Page Editor (Java) >> slot').nth(1).click();
    await this.page.waitForURL(`**/editor-view`);

    // Click text=Image Gallery (Java) >> slot >> nth=1
    await this.page.locator('text=Image Gallery (Java) >> slot').nth(1).click();
    await this.page.waitForURL(`**/image-list-view`);

    // Click text=Checkout Form (Java) >> slot >> nth=1
    await this.page.locator('text=Checkout Form (Java) >> slot').nth(1).click();
    await this.page.waitForURL(`**/checkout-form-view`);

    logger.success('Latest Java application test completed successfully');
  }
}

// Function to run the test (matching the original standalone script pattern)
export async function runLatestJavaTest(config: TestConfig): Promise<boolean> {
  const test = new LatestJavaTest(config);
  return await test.runTest();
}
