import { BaseTest, type TestConfig } from './baseTest.js';
import { logger } from '../utils/logger.js';

export class HybridTest extends BaseTest {
  constructor(config: TestConfig) {
    super(config);
  }

  override async runTest(): Promise<boolean> {
    return super.runTest(async () => {
      logger.info(`Executing HybridTest class from hybrid.test.ts`);
      await this.testHybridFunctionality();
    });
  }

  private async testHybridFunctionality(): Promise<void> {
    if (!this.page) {
      throw new Error('Page not initialized');
    }

    // Navigate to the main page
    await this.goto('/');

    // Test hybrid application functionality
    const hybridElement = this.page.locator('.hybrid-component, [data-testid="hybrid"], vaadin-hybrid');
    await hybridElement.waitFor({ state: 'visible', timeout: 30000 });
    
    logger.info('✓ Hybrid component loaded successfully');
  }
}

export async function runHybridTest(config: TestConfig): Promise<boolean> {
  const test = new HybridTest(config);
  return await test.runTest();
}
