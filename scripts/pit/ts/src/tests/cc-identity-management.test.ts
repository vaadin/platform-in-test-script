import { BaseTest, TestConfig } from './baseTest.js';
import { logger } from '../utils/logger.js';
import { expect } from '@playwright/test';
import { log, err, createPage, closePage, takeScreenshot, waitForServerReady, PageWithBrowser, TestArgs } from './testUtils.js';

export class CcIdentityManagementTest extends BaseTest {
  private readonly app = 'bakery-cc';
  private readonly role = 'admin';
  private readonly group = 'admin';
  private readonly user = 'admin@vaadin.com';
  private login?: string;
  private pass?: string;

  constructor(config: TestConfig & { login?: string; pass?: string }) {
    super(config);
    this.login = config.login;
    this.pass = config.pass;
  } TestConfig } from './baseTest.js';
import { logger } from '../utils/logger.js';
import { expect } from '@playwright/test';
import { log, err, createPage, closePage, takeScreenshot, waitForServerReady, PageWithBrowser } from './testUtils.js';

export class CcIdentityManagementTest extends BaseTest {
  private app = 'bakery-cc';
  private role = 'admin';
  private group = 'admin';
  private user = 'admin@vaadin.com';
  private login?: string;
  private pass?: string;

  constructor(config: TestConfig & { login?: string; pass?: string }) {
    super(config);
    this.login = config.login;
    this.pass = config.pass;
  }

  override async runTest(): Promise<boolean> {
    if (!this.login) {
      log(`Skipping the setup of Control center because of missing --email= parameter\n`);
      return false;
    }

    return super.runTest(async () => {
      logger.info(`Executing CcIdentityManagementTest class from cc-identity-management.test.ts`);
      await this.testIdentityManagement();
    });
  }

  private async testIdentityManagement(): Promise<void> {
    if (!this.page) {
      throw new Error('Page not initialized');
    }

    const checkboxSelectorRole = `//vaadin-grid-cell-content[.//text()="${this.role}"]/preceding-sibling::vaadin-grid-cell-content[1]//vaadin-checkbox//input`;
    const checkboxSelectorGroup = `//vaadin-grid-cell-content[.//text()="${this.group}"]/preceding-sibling::vaadin-grid-cell-content[1]//vaadin-checkbox//input`;
    const anchorSelectorURL = `//vaadin-grid-cell-content[.//span[normalize-space(text())="${this.app}"]]//a`;

    await waitForServerReady(this.page, this.config.url);

    await expect(this.page.getByLabel('Email')).toBeVisible();
    await takeScreenshot(this.page, __filename, 'view-loaded');

    // Login to Control Center
    log(`Logging in CC as ${this.login} ${this.pass}...\n`);
    await this.page.getByLabel('Email').fill(this.login!);
    await this.page.getByLabel('Password').fill(this.pass!);
    await this.page.getByRole('button', { name: 'Sign In' }).click();
    await takeScreenshot(this.page, __filename, 'logged-in');

    // Navigate to Settings and select app
    log(`Changing Settings for ${this.app}...\n`);
    await this.page.getByRole('link', { name: 'Settings' }).click();
    await takeScreenshot(this.page, __filename, 'settings');
    const appUrl = await this.page.locator(anchorSelectorURL).getAttribute('href');

    await this.page.locator('vaadin-select vaadin-input-container div').click();
    await this.page.getByRole('option', { name: this.app }).locator('div').nth(2).click();
    await takeScreenshot(this.page, __filename, 'selected-app');

    // Wait for Identity Management link to be enabled
    await this.waitForIdentityManagementEnabled(appUrl!);

    await this.page.waitForTimeout(2000);
    await this.page.getByRole('button', { name: 'Enable Identity Management' }).click();
    await takeScreenshot(this.page, __filename, 'identity-enabled');

    // Create role, group, and user
    await this.createRole();
    await this.createGroup(checkboxSelectorRole);
    await this.createUser(checkboxSelectorGroup);

    // Test login with created user
    await this.testUserLogin(appUrl!);

    // Cleanup
    await this.cleanup(appUrl!);
  }

  private async waitForIdentityManagementEnabled(appUrl: string): Promise<void> {
    if (!this.page) {
      throw new Error('Page not initialized');
    }

    let pageApp: PageWithBrowser | null = null;
    for (let attempt = 1; ; attempt++) {
      try {
        await this.page.getByRole('link', { name: 'Identity Management' }).click();
        await takeScreenshot(this.page, __filename, `identity-link-clicked-${attempt}`);
        break;
      } catch (error) {
        if (attempt > 3) throw error;
        log(`Attempt ${attempt}: Identity Management button not enabled yet.\n`);
        await takeScreenshot(this.page, __filename, `identity-link-not-enabled-${attempt}`);
        log(`Checking that ${this.app} installed in ${appUrl} is running ${attempt} ...\n`);
        
        pageApp = await createPage(this.config.headless ?? true, false);
        await waitForServerReady(pageApp, appUrl);
        await takeScreenshot(pageApp, __filename, `app-${this.app}-running-${attempt}`);
        await closePage(pageApp);
        await this.page.reload();
        await takeScreenshot(this.page, __filename, `app-${this.app}-running-retry-${attempt}`);
      }
    }
  }

  private async createRole(): Promise<void> {
    if (!this.page) return;

    log(`Adding Role...\n`);
    await this.page.getByRole('link', { name: 'Roles' }).click();
    await this.page.waitForTimeout(2000);
    await this.page.getByRole('button', { name: /New/ }).click();
    await takeScreenshot(this.page, __filename, 'role-form');
    await this.page.getByLabel('Name').fill(this.role);
    await this.page.getByLabel('Description').fill(this.role);
    await takeScreenshot(this.page, __filename, 'role-filled');
    await this.page.getByRole('contentinfo').getByRole('button', { name: 'Create' }).click();
    await takeScreenshot(this.page, __filename, 'role-created');
  }

  private async createGroup(checkboxSelectorRole: string): Promise<void> {
    if (!this.page) return;

    log(`Adding Group...\n`);
    await this.page.getByRole('link', { name: 'Groups' }).click();
    await this.page.waitForTimeout(2000);
    await this.page.getByRole('button', { name: /New/ }).click();
    await takeScreenshot(this.page, __filename, 'group-form');
    await this.page.getByLabel('Name').fill(this.group);
    await this.page.locator(checkboxSelectorRole).click();
    await takeScreenshot(this.page, __filename, 'group-filled');
    await this.page.getByRole('contentinfo').getByRole('button', { name: 'Create' }).click();
    await takeScreenshot(this.page, __filename, 'group-created');
  }

  private async createUser(checkboxSelectorGroup: string): Promise<void> {
    if (!this.page) return;

    log(`Adding User...\n`);
    await this.page.getByRole('link', { name: 'Users' }).click();
    await this.page.waitForTimeout(2000);
    await this.page.getByRole('button', { name: /New/ }).click();
    await takeScreenshot(this.page, __filename, 'user-form');
    await this.page.getByLabel('First Name').fill(this.role);
    await this.page.getByLabel('Last Name').fill('user');
    await this.page.getByLabel('E-mail Address').fill(this.user);
    await this.page.getByLabel('Password', { exact: true }).fill(this.role);
    await this.page.locator(checkboxSelectorGroup).click();
    await takeScreenshot(this.page, __filename, 'user-filled');
    await this.page.getByRole('contentinfo').getByRole('button', { name: 'Create' }).click();
    await takeScreenshot(this.page, __filename, 'user-created');
  }

  private async testUserLogin(appUrl: string): Promise<void> {
    log(`Logging in ${this.app} as ${this.user} ...\n`);
    const pageApp = await createPage(this.config.headless ?? true, false);
    await waitForServerReady(pageApp, appUrl);
    await takeScreenshot(pageApp, __filename, `app-${this.app}-loaded`);
    await pageApp.getByLabel('Email').fill(this.user);
    
    try {
      await pageApp.getByLabel('Password').fill(this.role, { timeout: 1000 });
    } catch {
      log('Password not found in the first dialog, trying the second one (cc vers 1.2+)...\n');
      await pageApp.getByRole('button', { name: 'Sign In' }).click();
      await takeScreenshot(pageApp, __filename, `app-${this.app}-password-dialog`);
    }
    
    await pageApp.getByLabel('Password').fill(this.role);
    await pageApp.getByRole('button', { name: 'Sign In' }).click();
    await takeScreenshot(pageApp, __filename, `logged-in-${this.app}`);
    await expect(pageApp.getByRole('button', { name: 'New order' })).toBeVisible();
    await closePage(pageApp);
  }

  private async cleanup(appUrl: string): Promise<void> {
    if (!this.page) return;

    log('Cleaning up...\n');
    try {
      // Delete role
      await this.page.getByRole('link', { name: 'Roles' }).click();
      await this.page.waitForTimeout(2000);
      await this.page.getByText(this.role, { exact: true }).nth(1).click();
      await this.page.getByRole('button', { name: 'Delete' }).click();
      await this.page.locator('vaadin-confirm-dialog-overlay').getByRole('button', { name: 'Delete' }).click();
      
      // Delete group
      await this.page.getByRole('link', { name: 'Groups' }).click();
      await this.page.waitForTimeout(2000);
      await this.page.getByText(this.group, { exact: true }).click();
      await this.page.getByRole('button', { name: 'Delete' }).click();
      await this.page.locator('vaadin-confirm-dialog-overlay').getByRole('button', { name: 'Delete' }).click();
      
      // Delete user
      await this.page.getByRole('link', { name: 'Users' }).click();
      await this.page.waitForTimeout(2000);
      await this.page.getByText(this.user, { exact: true }).click();
      await this.page.getByRole('button', { name: 'Delete' }).click();
      await this.page.locator('vaadin-confirm-dialog-overlay').getByRole('button', { name: 'Delete' }).click();
      
      // Disable identity management
      await this.page.getByRole('link', { name: 'Settings' }).click();
      await this.page.waitForTimeout(2000);
      await this.page.locator('vaadin-grid').getByText('bakery-cc', { exact: true }).click();
      await this.page.getByLabel('Replicas').fill('0');
      await this.page.getByLabel('Identity Management').uncheck();
      await this.page.getByRole('button', { name: 'Disable' }).click();
      await this.page.getByRole('button', { name: 'Update' }).click();
      await this.page.waitForTimeout(500);
      await this.page.getByLabel('Startup Delay (secs)').fill('30');
      await this.page.getByLabel('Replicas').fill('1');
      await this.page.getByRole('button', { name: 'Update' }).click();

      const pageApp = await createPage(this.config.headless ?? true, false);
      await waitForServerReady(pageApp, appUrl);
      await takeScreenshot(pageApp, __filename, 'app-after-cleanup');
      await closePage(pageApp);
    } catch (error) {
      err(`Error cleaning up: ${error}\n`);
      await takeScreenshot(this.page, __filename, 'error-cleaning');
    }

    logger.success('CC Identity Management test completed successfully');
  }
}

// Function to run the test (matching the original standalone script pattern)
export async function runCcIdentityManagementTest(config: TestConfig & { login?: string; pass?: string }): Promise<boolean> {
  const test = new CcIdentityManagementTest(config);
  return await test.runTest();
}
