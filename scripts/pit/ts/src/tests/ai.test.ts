import { BaseTest, TestConfig } from './baseTest.js';
import { logger } from '../utils/logger.js';

export class AiTest extends BaseTest {
  constructor(config: TestConfig) {
    super(config);
  }

  override async runTest(): Promise<boolean> {
    return super.runTest(async () => {
      logger.info(`Executing AiTest class from ai.test.ts`);
      await this.testAiFormFilling();
    });
  }

  private async testAiFormFilling(): Promise<void> {
    if (!this.page) {
      throw new Error('Page not initialized');
    }

    // Navigate to the main page
    await this.goto('/');

    // Fill the invoice form text
    const invoiceText = `Jose Macias Pajas\t\t\tFactura / Invoice\t\t\nNIF: 111222333-S\t \t\t\tFecha / Date\t25 jul 2021\nEU VAT: FR111222333S\t\t\t\tFact.Núm / Invoice #\t12345\nIrlandeses, 7\t \t\t\t\t\n28800, AH, MAD, ES\t\t\t\t\t\n(+34) 653454512\n\t\t\t\t\t\nPara / Bill for\t\t\t\t\t\nPickup Oy\t\t\t\t\t\nFI3456\nRoad Ji 2-4\t\t\t\t\t\nHelsinki, Finland. FI.\t\t\t\t\t\n\t\t\t\t\t\nDescripción / Description\t\t\tCant. / Q.\tPrecio / Rate\tImporte / Amount\n\t\t\t\t\t\nSoftware Development Services\t\t\t1\t3.000,00 €\t3.000,00 €\n\t\t\t\t\t\nInternet Connection costs\t\t\t1\t13,89 €\t13,89 €\n\t\t\t\t\t\nHealth Insurance costs\t\t\t1\t40,16 €\t40,16 €\n\t\t\t\t\t\nTrips & Extra costs\t\t\t1\t\t50,00 €\n\t\t\t\t\t\n\t\t\t\tVAT\t50 €\n\t\t\t\tTotal\t7.439,05 €\n\t\t\t\t\t\nE-mail: aaa@example.org\t\t\t\t\t`;

    await this.page.getByLabel('Input Text').fill(invoiceText);
    await this.page.getByRole('button', { name: 'Fill the form' }).locator('span').nth(1).click();

    // Wait for the form to be filled and check the total
    await this.waitForOrderTotal('7439.05');

    logger.success('AI form filling test completed successfully');
  }

  private async waitForOrderTotal(expectedTotal: string): Promise<void> {
    if (!this.page) {
      throw new Error('Page not initialized');
    }

    const maxAttempts = 10;
    const sleepMs = 3000;

    for (let i = 1; i < maxAttempts; i++) {
      const txt = await this.page.getByLabel('Order total').inputValue();
      if (txt === expectedTotal) {
        logger.info(`Order total correctly filled: ${txt}`);
        return;
      }
      await new Promise(resolve => setTimeout(resolve, sleepMs));
    }

    throw new Error(`Timeout waiting for order total to be ${expectedTotal}`);
  }
}

// Function to run the test (matching the original standalone script pattern)
export async function runAiTest(config: TestConfig): Promise<boolean> {
  const test = new AiTest(config);
  return await test.runTest();
}
