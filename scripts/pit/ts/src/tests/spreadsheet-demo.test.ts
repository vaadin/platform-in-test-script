import { BaseTest, TestConfig } from './baseTest.js';
import { logger } from '../utils/logger.js';

export class SpreadsheetDemoTest extends BaseTest {
  constructor(config: TestConfig) {
    super(config);
  }

  override async runTest(): Promise<boolean> {
    return super.runTest(async () => {
      logger.info(`Executing SpreadsheetDemoTest class from spreadsheet-demo.test.ts`);
      await this.testSpreadsheetDemoApplication();
    });
  }

  private async testSpreadsheetDemoApplication(): Promise<void> {
    if (!this.page) {
      throw new Error('Page not initialized');
    }

    // Set up extra headers
    await this.page.setExtraHTTPHeaders({
      'X-AppUpdate': 'FOO'
    });

    // Navigate to the main page
    await this.goto('/');

    // Dismiss Vaadin live reload notifications
    await this.page.evaluate(() => {
      window.localStorage.setItem("vaadin.live-reload.dismissedNotifications","liveReloadUnavailable,preserveOnRefreshWarning");
      window.location.reload();
    });

    // Click on Basic functionality
    await this.page.getByRole('link', { name: 'Basic functionality' }).click();
    await this.page.waitForURL(`**/demo/basic`);

    // Click on the first col2 element
    await this.page.locator('.col2').first().click();
    await this.page.waitForTimeout(100);

    // Verify SIMPLE MONTHLY BUDGET text appears
    const count = await this.page.getByText('SIMPLE MONTHLY BUDGET').count();
    if (count === 0) {
      throw new Error('Expected SIMPLE MONTHLY BUDGET text not found');
    }

    // Click on col3 then input field
    await this.page.locator('.col3').first().click();
    await this.page.locator('input').first().fill('3000');
    await this.page.keyboard.press('Enter');

    // Click on the col5 elements
    await this.page.locator('.col5').first().click();
    await this.page.locator('input').first().fill('=C2*12');
    await this.page.keyboard.press('Enter');

    // Click on HVAC in demo navigation
    await this.page.getByRole('link', { name: 'HVAC' }).click();
    await this.page.waitForURL(`**/demo/hvac`);

    // Verify HVAC text appears
    await this.page.getByText('HVAC Calculations').click();

    // Click on Bigger sheet demo
    await this.page.getByRole('link', { name: 'Bigger sheet' }).click();
    await this.page.waitForURL(`**/demo/big`);

    // Click on a cell in the bigger sheet
    await this.page.getByText('WORLD').click();

    // Navigate to Report mode
    await this.page.getByRole('link', { name: 'Report mode' }).click();
    await this.page.waitForURL(`**/demo/reportMode`);
    await this.page.getByText('547 Demo Suites #85').click();

    // Navigate to Simple invoice
    await this.page.getByRole('link', { name: 'Simple invoice' }).click();
    await this.page.waitForURL(`**/demo/simpleInvoice`);
    await this.page.getByText('547 Demo Suites #85').click();

    logger.success('Spreadsheet demo test completed successfully');
  }
}

// Function to run the test (matching the original standalone script pattern)
export async function runSpreadsheetDemoTest(config: TestConfig): Promise<boolean> {
  const test = new SpreadsheetDemoTest(config);
  return await test.runTest();
}
