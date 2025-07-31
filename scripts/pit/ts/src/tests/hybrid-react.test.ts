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

    // Test basic functionality - look for hybrid react components
    const reactComponent = this.page.locator('[data-testid="react-component"], .react-component, react-view');
    await reactComponent.waitFor({ state: 'visible', timeout: 30000 });
    
    logger.info('✓ Hybrid React component loaded successfully');

    // Test navigation or interaction if available
    const navLinks = this.page.locator('vaadin-tabs tab, a[href*="react"], [role="tab"]');
    const navCount = await navLinks.count();
    
    if (navCount > 0) {
      await navLinks.first().click();
      await this.page.waitForLoadState('networkidle');
      logger.info('✓ Navigation in hybrid React app working');
    } else {
      logger.info('✓ Basic hybrid React app validation completed');
    }
  }
}

export async function runHybridReactTest(config: TestConfig): Promise<boolean> {
  const test = new HybridReactTest(config);
  return await test.runTest();
}
