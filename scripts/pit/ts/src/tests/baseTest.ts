import { chromium, Browser, BrowserContext, Page } from 'playwright';
import { logger } from '../utils/logger.js';

export interface TestConfig {
  url: string;
  starter?: string;
  mode?: string;
  version?: string;
  headless?: boolean;
  host?: string;
  port?: number;
  timeout?: number;
}

export class BaseTest {
  protected browser: Browser | null = null;
  protected context: BrowserContext | null = null;
  protected page: Page | null = null;
  protected config: TestConfig;

  constructor(config: TestConfig) {
    this.config = config;
  }

  async setup(): Promise<void> {
    try {
      logger.info(`Setting up Playwright browser...`);
      logger.debug(`Browser Configuration:`);
      logger.debug(`  ├─ Headless: ${this.config.headless ?? true}`);
      logger.debug(`  ├─ Host: ${this.config.host ?? 'localhost'}`);
      logger.debug(`  ├─ Port: ${this.config.port ?? 8080}`);
      logger.debug(`  └─ Timeout: ${this.config.timeout ?? 30000}ms`);

      this.browser = await chromium.launch({
        headless: this.config.headless ?? true,
        args: ['--no-sandbox', '--disable-setuid-sandbox'] // chromiumSandbox: false equivalent
      });

      this.context = await this.browser.newContext();

      this.page = await this.context.newPage();

      // Set up console and error logging
      this.page.on('console', msg => {
        const location = msg.location();
        const text = `${msg.text()} - ${location.url}`.replace(/\s+/g, ' ');
        logger.debug(`> CONSOLE: ${text}`);
      });

      this.page.on('pageerror', err => {
        const text = String(err).replace(/\s+/g, ' ');
        logger.warn(`> PAGEERROR: ${text}`);
      });

      this.page.setDefaultTimeout(this.config.timeout ?? 30000);

    } catch (error) {
      logger.error(`Failed to setup test browser: ${error}`);
      throw error;
    }
  }

  async teardown(): Promise<void> {
    try {
      if (this.page) {
        await this.page.close();
        this.page = null;
      }
      if (this.context) {
        await this.context.close();
        this.context = null;
      }
      if (this.browser) {
        await this.browser.close();
        this.browser = null;
      }
    } catch (error) {
      logger.warn(`Error during test teardown: ${error}`);
    }
  }

  protected async goto(path: string = '/'): Promise<void> {
    if (!this.page) {
      throw new Error('Page not initialized. Call setup() first.');
    }

    const url = `http://${this.config.host ?? 'localhost'}:${this.config.port ?? 8080}${path}`;
    logger.debug(`Navigating to: ${url}`);
    await this.page.goto(url);
  }

  protected async waitForElement(selector: string, timeout?: number): Promise<void> {
    if (!this.page) {
      throw new Error('Page not initialized. Call setup() first.');
    }

    const finalTimeout = timeout || 3000; // Default 3 seconds for element waiting
    await this.page.waitForSelector(selector, { timeout: finalTimeout });
  }

  protected async clickElement(selector: string): Promise<void> {
    if (!this.page) {
      throw new Error('Page not initialized. Call setup() first.');
    }

    await this.page.locator(selector).click();
  }

  protected async fillInput(selector: string, value: string): Promise<void> {
    if (!this.page) {
      throw new Error('Page not initialized. Call setup() first.');
    }

    await this.page.locator(selector).fill(value);
  }

  protected async waitForURL(url: string, timeout: number): Promise<void> {
    if (!this.page) {
      throw new Error('Page not initialized. Call setup() first.');
    }

    await this.page.waitForURL(url, { timeout: timeout });
  }

  protected async expectElement(selector: string): Promise<void> {
    if (!this.page) {
      throw new Error('Page not initialized. Call setup() first.');
    }

    const element = this.page.locator(selector);
    await element.waitFor({ state: 'visible' });
  }

  private screenshotCount = 0;
  protected async takeScreenshot(description: string): Promise<void> {
    if (!this.page) {
      throw new Error('Page not initialized. Call setup() first.');
    }

    // Skip screenshots in fast mode
    if (process.env['FAST']) return;

    const cnt = String(++this.screenshotCount).padStart(2, "0");
    const testName = this.constructor.name.replace('Test', '').toLowerCase();
    const file = `screenshots.out/${testName}-${cnt}-${description}.png`;
    
    // Wait a bit for UI to settle
    let timeout = 200;
    if (process.platform.startsWith('win')) {
      timeout = 10000;
    } else if (process.env['GITHUB_ACTIONS']) {
      timeout = 800;
    }
    
    await this.page.waitForTimeout(timeout);
    await this.page.screenshot({ path: file });
    logger.debug(`📸 Screenshot taken: ${file}`);
  }

  // Utility method to run a complete test
  async runTest(testFunction: () => Promise<void>): Promise<boolean> {
    try {
      await this.setup();
      await testFunction();
      logger.success('Test completed successfully');
      return true;
    } catch (error) {
      logger.error(`Test failed: ${error}`);
      return false;
    } finally {
      await this.teardown();
    }
  }
}

// Utility functions for time computation (matching the JavaScript version)
export function computeTime(): string {
  if (!process.env['START']) return "";
  const timeElapsed = Math.floor(Date.now() / 1000) - parseInt(process.env['START'] || '0');
  const mins = Math.floor(timeElapsed / 60);
  const secs = timeElapsed % 60;
  const str = `${String(mins).padStart(2, '0')}'${String(secs).padStart(2, '0')}"`;
  return `\x1b[2;36m - ${str}\x1b[0m`;
}

export function log(...args: any[]): void {
  const timeStr = computeTime();
  logger.info(`${args.join(' ')}${timeStr}`);
}
