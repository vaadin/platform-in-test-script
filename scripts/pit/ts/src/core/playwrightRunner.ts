import { chromium, Browser, BrowserContext, Page } from '@playwright/test';
import type { PitConfig } from '../types.js';
import { logger } from '../utils/logger.js';
import { runCommand } from '../utils/system.js';
import { fileExists } from '../utils/file.js';

export interface PlaywrightTestOptions {
  port: number;
  mode: 'dev' | 'prod';
  name: string;
  version: string;
  headless: boolean;
}

export class PlaywrightRunner {
  private readonly config: PitConfig;

  constructor(config: PitConfig) {
    this.config = config;
  }

  async runTests(testFile: string, options: PlaywrightTestOptions): Promise<void> {
    if (!(await fileExists(testFile))) {
      logger.info(`No test file found: ${testFile}`);
      return;
    }

    logger.info(`Running Playwright tests: ${testFile}`);

    // Check if Playwright is installed
    await this.ensurePlaywrightInstalled();

    // Run the test file with Node.js
    const args = [
      `--port=${options.port}`,
      `--name=${options.name}`,
      `--version=${options.version}`,
      `--mode=${options.mode}`,
    ];

    if (options.headless) {
      args.push('--headless');
    }

    const command = `node "${testFile}" ${args.join(' ')}`;
    const result = await runCommand(command);

    if (!result.success) {
      throw new Error(`Playwright tests failed: ${result.stderr}`);
    }

    logger.success('✓ Playwright tests completed successfully');
  }

  private async ensurePlaywrightInstalled(): Promise<void> {
    // Check if @playwright/test is installed
    try {
      await runCommand('npx playwright --version');
    } catch {
      logger.info('Installing Playwright...');
      
      // Install Playwright
      const installResult = await runCommand('npm install @playwright/test');
      if (!installResult.success) {
        throw new Error(`Failed to install Playwright: ${installResult.stderr}`);
      }

      // Install browsers
      const browsersResult = await runCommand('npx playwright install chromium');
      if (!browsersResult.success) {
        throw new Error(`Failed to install Playwright browsers: ${browsersResult.stderr}`);
      }

      // Install system dependencies (Linux only)
      if (process.platform === 'linux') {
        await runCommand('npx playwright install-deps chromium');
      }
    }
  }

  /**
   * Create a Playwright test programmatically (alternative to running existing JS files)
   */
  async createAndRunTest(
    testName: string,
    url: string,
    testActions: (page: Page) => Promise<void>
  ): Promise<void> {
    let browser: Browser | null = null;
    let context: BrowserContext | null = null;

    try {
      await this.ensurePlaywrightInstalled();

      browser = await chromium.launch({
        headless: this.config.headless,
      });

      context = await browser.newContext();
      const page = await context.newPage();

      // Set up console and error logging
      page.on('console', (msg) => {
        logger.info(`> CONSOLE: ${msg.text()}`);
      });

      page.on('pageerror', (err) => {
        logger.error(`> PAGEERROR: ${err.message}`);
      });

      // Navigate to the URL
      await page.goto(url, { waitUntil: 'networkidle' });

      // Run the test actions
      await testActions(page);

      logger.success(`✓ ${testName} test completed successfully`);

    } catch (error) {
      logger.error(`✗ ${testName} test failed: ${error}`);
      throw error;
    } finally {
      if (context) {
        await context.close();
      }
      if (browser) {
        await browser.close();
      }
    }
  }

  /**
   * Run a default starter test (clicks Hello button and checks response)
   */
  async runDefaultStarterTest(url: string): Promise<void> {
    await this.createAndRunTest('Default Starter', url, async (page) => {
      // Wait for the page to load
      await page.waitForSelector('text=Hello', { timeout: 10000 });

      // Click the Hello button
      await page.locator('text=Hello').first().click();

      // Fill in the text field
      await page.locator('input[type="text"]').fill('Test User');

      // Click "Say hello" button
      await page.locator('text=Say hello').click();

      // Check for the greeting message
      await page.locator('text=Hello Test User').waitFor({ timeout: 5000 });
    });
  }

  /**
   * Run a React starter test
   */
  async runReactStarterTest(url: string): Promise<void> {
    await this.createAndRunTest('React Starter', url, async (page) => {
      // Wait for React app to load
      await page.waitForSelector('[data-testid="increment-button"], button:has-text("Increment")', { 
        timeout: 10000 
      });

      // Click increment button multiple times
      const incrementButton = page.locator('[data-testid="increment-button"], button:has-text("Increment")').first();
      await incrementButton.click();
      await incrementButton.click();
      await incrementButton.click();

      // Check that counter has incremented
      await page.locator('text=3').waitFor({ timeout: 5000 });
    });
  }
}
