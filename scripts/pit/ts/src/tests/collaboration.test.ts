import { BaseTest, type TestConfig } from './baseTest.js';
import { logger } from '../utils/logger.js';
import { chromium } from 'playwright';
import type { Browser, BrowserContext, Page } from 'playwright';
import { killPlaywrightProcesses } from '../utils/system.js';

export class CollaborationTest extends BaseTest {
  private browser2: Browser | undefined;
  private context2: BrowserContext | undefined;
  private page2: Page | undefined;
  private secondBrowserSetup = false;

  constructor(config: TestConfig) {
    super(config);
  }

  override async runTest(): Promise<boolean> {
    try {
      return await super.runTest(async () => {
        logger.info(`Executing CollaborationTest class from collaboration.test.ts`);
        await this.setupSecondBrowser();
        await this.testCollaborationFlow();
      });
    } finally {
      // Ensure second browser cleanup happens regardless of test outcome
      await this.cleanupSecondBrowser();
    }
  }

  // Override teardown to also cleanup the second browser with extra safety
  override async teardown(): Promise<void> {
    try {
      // Clean up second browser first with timeout
      await Promise.race([
        this.cleanupSecondBrowser(),
        new Promise((_, reject) => 
          setTimeout(() => reject(new Error('Second browser cleanup timeout')), 10000)
        )
      ]);
    } catch (error) {
      logger.error(`Error during second browser cleanup: ${error}`);
      // Continue with parent cleanup even if second browser cleanup fails
    } finally {
      // Then call parent teardown for the main browser
      await super.teardown();
    }
  }

  private async setupSecondBrowser(): Promise<void> {
    if (this.secondBrowserSetup) {
      logger.debug('Second browser already set up, skipping...');
      return;
    }

    logger.debug('Setting up second browser for collaboration testing...');
    
    // Set up second browser for collaboration testing
    this.browser2 = await chromium.launch({
      headless: this.config.headless ?? true,
      args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    
    this.context2 = await this.browser2.newContext();
    this.page2 = await this.context2.newPage();
    
    // Set up console logging for second page
    this.page2.on('console', msg => 
      logger.debug(`PAGE2 CONSOLE: ${msg.text()} - ${msg.location().url}`)
    );
    this.page2.on('pageerror', err => 
      logger.error(`PAGE2 PAGEERROR: ${err}`)
    );

    this.secondBrowserSetup = true;
    logger.debug('Second browser setup completed');
  }

  private async cleanupSecondBrowser(): Promise<void> {
    if (!this.secondBrowserSetup) {
      logger.debug('Second browser not set up, skipping cleanup...');
      return;
    }

    try {
      if (this.page2) {
        logger.debug('Closing second browser page...');
        await this.page2.close();
        this.page2 = undefined;
      }
      
      if (this.context2) {
        logger.debug('Closing second browser context...');
        await this.context2.close();
        this.context2 = undefined;
      }
      
      if (this.browser2) {
        logger.debug('Closing second browser...');
        await this.browser2.close();
        this.browser2 = undefined;
      }
      
      this.secondBrowserSetup = false;
      logger.debug('Second browser cleanup completed');

      // As a final safety measure, kill any remaining Playwright processes
      await killPlaywrightProcesses();
      
    } catch (error) {
      logger.error(`Error during second browser cleanup: ${error}`);
      // Don't throw, we want to continue with the rest of cleanup
    }
  }

  private async testCollaborationFlow(): Promise<void> {
    if (!this.page || !this.page2) {
      throw new Error('Pages not initialized');
    }

    // Navigate both users to the application
    await this.goto('/');
    await this.page2.goto(`http://${this.config.host}:${this.config.port}/`);
    
    logger.info('✓ Both users connected to the application');

    // Test chat functionality
    await this.testChatFunctionality();
    
    // Test avatar display
    await this.testAvatarDisplay();
    
    // Test collaborative editing
    await this.testCollaborativeEditing();
  }

  private async testChatFunctionality(): Promise<void> {
    if (!this.page || !this.page2) return;

    logger.info('Testing chat functionality...');

    // User 1 sends a message
    await this.page.getByText('#support').click();
    await this.page.getByText('#casual').click();
    await this.page.getByText('#general').click();
    await this.page.getByLabel('Message').click();
    await this.page.getByLabel('Message').fill('Test from user 1');
    await this.page.getByRole('button', { name: 'Send' }).click();

    // User 2 receives and replies
    await this.page2.getByText('#general').click();
    await this.page2.getByText('Test from user 1');
    await this.page2.getByLabel('Message').click();
    await this.page2.getByLabel('Message').fill('Test from user 2');
    await this.page2.getByRole('button', { name: 'Send' }).click();

    // User 1 receives reply
    await this.page.getByText('Test from user 2');
    
    logger.info('✓ Chat functionality working correctly');
  }

  private async testAvatarDisplay(): Promise<void> {
    if (!this.page || !this.page2) return;

    logger.info('Testing avatar display...');

    // Check avatar groups
    // There is always one more avatar in the group than there are users 
    // (which displays the number of non-visible 'other' avatars, i.e., the overflow.)
    const expectedAvatarCount = 2 + 1;

    const avatarCount1 = await this.page.locator('vaadin-avatar-group > vaadin-avatar').count();
    if (avatarCount1 !== expectedAvatarCount) {
      throw new Error(`Expected ${expectedAvatarCount - 1} users but found: ${avatarCount1 - 1}`);
    }

    const avatarCount2 = await this.page2.locator('vaadin-avatar-group > vaadin-avatar').count();
    if (avatarCount2 !== expectedAvatarCount) {
      throw new Error(`Expected ${expectedAvatarCount - 1} users but found: ${avatarCount2 - 1}`);
    }
    
    logger.info('✓ Avatar display working correctly');
  }

  private async testCollaborativeEditing(): Promise<void> {
    if (!this.page || !this.page2) return;

    logger.info('Testing collaborative editing...');

    // User 1 edits an entry
    await this.page.getByRole('link', { name: 'Master Detail' }).click();
    await this.page.getByText('Gene', { exact: true }).click();
    await this.page.waitForTimeout(1000);
    await this.page.getByLabel('First Name', { exact: true }).click();
    await this.page.getByLabel('First Name', { exact: true }).fill('Gene James');
    await this.page.getByRole('button', { name: 'Save' }).click();
    
    // Wait for the notification of data updated
    await this.page.getByRole('alert').count();
    
    logger.info('✓ User 1 made changes');

    // User 2 checks if changes appear
    await this.page2.getByRole('link', { name: 'Master Detail' }).click();
    await this.page.waitForTimeout(1000);
    await this.page2.waitForTimeout(1000);
    await this.page.reload();
    await this.page2.reload();

    await this.page2.getByText('Gene James', { exact: true }).click();
    await this.page.waitForTimeout(1000);
    await this.page2.getByLabel('First Name', { exact: true }).fill('Gene James, 3rd');
    await this.page2.getByRole('button', { name: 'Save' }).click();
    
    // Wait for the notification of data updated
    await this.page2.getByRole('alert').count();
    
    logger.info('✓ User 2 made changes');

    // Verify changes are visible to user 1
    await this.page.waitForTimeout(1000);
    await this.page2.waitForTimeout(1000);
    await this.page.reload();
    await this.page2.reload();

    await this.page.getByText('Gene James, 3rd', { exact: true }).click();
    
    logger.info('✓ Collaborative editing working correctly');
  }
}

export async function runCollaborationTest(config: TestConfig): Promise<boolean> {
  const test = new CollaborationTest(config);
  return await test.runTest();
}
