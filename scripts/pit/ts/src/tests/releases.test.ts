import { BaseTest, TestConfig } from './baseTest.js';
import { logger } from '../utils/logger.js';
import { expect } from '@playwright/test';
import { dismissDevmode } from './testUtils.js';

export class ReleasesTest extends BaseTest {
  constructor(config: TestConfig) {
    super(config);
  }

  override async runTest(): Promise<boolean> {
    return super.runTest(async () => {
      logger.info(`Executing ReleasesTest class from releases.test.ts`);
      await this.testReleasesApplication();
    });
  }

  private async testReleasesApplication(): Promise<void> {
    if (!this.page) {
      throw new Error('Page not initialized');
    }

    // Navigate to the main page and wait for it to be ready
    await this.goto('/');

    // Get page HTML to ensure it's loaded
    await this.page.locator('html').first().innerHTML();
    await this.takeScreenshot('view1-loaded');

    // Dismiss dev mode if present
    if (await dismissDevmode(this.page)) {
      await this.takeScreenshot('dev-mode-indicator-closed');
    }

    // Verify Pre-releases per version text is visible
    await expect(this.page.getByText('Pre-releases per version').first()).toBeVisible();

    // Click on "by release count"
    await this.page.getByText('by release count').click();

    await this.takeScreenshot('view3-loaded');
    await expect(this.page.getByText('Releases per version').first()).toBeVisible();

    // Get version from config and create regex
    const version = this.config.version || '24.4';
    const [major, minor] = version.split('.');
    const labelRegex = new RegExp(`${major}\\.${minor}, `);
    
    // Click on the version label
    await this.page.getByLabel(labelRegex).click();
    await this.takeScreenshot(`element-${labelRegex}-clicked`);

    // Click on the chart point for this version
    const selector = `path.highcharts-point[aria-label*="${version},"]`;
    await this.page.locator(selector).click();
    await this.takeScreenshot(`chart-point-${version}-clicked`);

    // Verify chart changes
    await expect(this.page.getByText('Releases').first()).toBeVisible();

    logger.success('Releases application test completed successfully');
  }
}

// Function to run the test (matching the original standalone script pattern)
export async function runReleasesTest(config: TestConfig): Promise<boolean> {
  const test = new ReleasesTest(config);
  return await test.runTest();
}
