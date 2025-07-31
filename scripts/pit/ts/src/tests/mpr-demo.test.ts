import { BaseTest, type TestConfig } from './baseTest.js';
import { logger } from '../utils/logger.js';

export class MprDemoTest extends BaseTest {
  constructor(config: TestConfig) {
    super(config);
  }

  override async runTest(): Promise<boolean> {
    return super.runTest(async () => {
      logger.info(`Executing MprDemoTest class from mpr-demo.test.ts`);
      await this.testMprDemoFunctionality();
    });
  }

  private async testMprDemoFunctionality(): Promise<void> {
    if (!this.page) {
      throw new Error('Page not initialized');
    }

    // Navigate to the main page
    await this.goto('/');

    // Test MPR (Multi-Platform Runtime) specific functionality
    // Look for spreadsheet or demo components
    const demoElement = this.page.locator('vaadin-spreadsheet, .mpr-demo, [data-testid="mpr-demo"]');
    await demoElement.waitFor({ state: 'visible', timeout: 30000 });
    
    logger.info('✓ MPR Demo component loaded successfully');

    // Test basic interaction if available
    const interactiveElements = this.page.locator('button, vaadin-button, [role="button"]');
    const elementCount = await interactiveElements.count();
    
    if (elementCount > 0) {
      await interactiveElements.first().click();
      await this.page.waitForTimeout(2000);
      logger.info('✓ Basic interaction with MPR demo working');
    } else {
      logger.info('✓ Basic MPR demo validation completed');
    }
  }
}

export async function runMprDemoTest(config: TestConfig): Promise<boolean> {
  const test = new MprDemoTest(config);
  return await test.runTest();
}
