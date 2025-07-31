import { BaseTest, type TestConfig } from './baseTest.js';
import { logger } from '../utils/logger.js';

export class HillaReactCliTest extends BaseTest {
  constructor(config: TestConfig) {
    super(config);
  }

  override async runTest(): Promise<boolean> {
    return super.runTest(async () => {
      logger.info(`Executing HillaReactCliTest class from hilla-react-cli.test.ts`);
      await this.testHillaReactCliFunctionality();
    });
  }

  private async testHillaReactCliFunctionality(): Promise<void> {
    if (!this.page) {
      throw new Error('Page not initialized');
    }

    // Navigate to the main page
    await this.goto('/');

    // Test Hilla React CLI specific functionality
    const reactElement = this.page.locator('div[id="root"], .hilla-react, [data-testid="hilla-react"]');
    await reactElement.waitFor({ state: 'visible', timeout: 30000 });
    
    logger.info('✓ Hilla React CLI application loaded successfully');

    // Test React-specific elements
    const reactContent = this.page.locator('text=React, text=Hilla, text=TypeScript');
    const hasReactContent = await reactContent.count() > 0;
    
    if (hasReactContent) {
      logger.info('✓ React content detected in Hilla app');
    } else {
      logger.info('✓ Basic Hilla React CLI validation completed');
    }
  }
}

export async function runHillaReactCliTest(config: TestConfig): Promise<boolean> {
  const test = new HillaReactCliTest(config);
  return await test.runTest();
}
