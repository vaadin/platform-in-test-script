import { BaseTest, type TestConfig } from './baseTest.js';
import { logger } from '../utils/logger.js';

export class HybridReactTest extends BaseTest {
  constructor(config: TestConfig) {
    super(config);
  }

  override async runTest(): Promise<boolean> {
    return super.runTest(async () => {
      logger.info(`Executing HybridReactTest class from hybrid-react.test.ts`);
      await this.testHybridReactFunctionality();
    });
  }

  private async testHybridReactFunctionality(): Promise<void> {
    if (!this.page) {
      throw new Error('Page not initialized');
    }

    // Navigate to the main page
    await this.goto('/');

    // Test Hello Flow functionality (Flow part of hybrid app)
    await this.page.locator('text=Hello Flow').nth(0).click();
    await this.page.locator('text=eula.lane').click();
    await this.page.locator('input[type="text"]').nth(0).fill('FOO');
    await this.page.locator('text=Save').click();
    await this.page.locator('text=/updated/').waitFor({ state: 'visible' });
    
    logger.info('✓ Hello Flow functionality verified');

    // Test Hello Hilla functionality (React part of hybrid app)
    await this.page.locator('text=Hello Hilla').nth(0).click();
    await this.page.locator('text=/This place intentionally left empty/').waitFor({ state: 'visible' });
    
    logger.info('✓ Hello Hilla functionality verified');
    logger.success('Hybrid React application test completed successfully');
  }
}

export async function runHybridReactTest(config: TestConfig): Promise<boolean> {
  const test = new HybridReactTest(config);
  return await test.runTest();
}
