const { expect} = require('@playwright/test');
const {log, err, args, createPage, closePage, takeScreenshot, waitForServerReady} = require('./test-utils');

(async () => {
    const arg = args();
    if (!arg.login) {
        log(`Skipping the setup of Control center because of missing --email= parameter\n`)
        process.exit(1);
    }
    const app = `bakery-cc`;
    const role = 'admin';
    const group = 'admin';
    const user = 'admin@vaadin.com';
    const checkboxSelectorRole = `//vaadin-grid-cell-content[.//text()="${role}"]/preceding-sibling::vaadin-grid-cell-content[1]//vaadin-checkbox//input`;
    const checkboxSelectorGroup = `//vaadin-grid-cell-content[.//text()="${group}"]/preceding-sibling::vaadin-grid-cell-content[1]//vaadin-checkbox//input`;
    const anchorSelectorURL = `//vaadin-grid-cell-content[.//span[normalize-space(text())="${app}"]]//a`;

    const page = await createPage(arg.headless, arg.ignoreHTTPSErrors);
    await waitForServerReady(page, arg.url);

    await expect(page.getByLabel('Email')).toBeVisible();
    await takeScreenshot(page, __filename, 'view-loaded');

    log(`Logging in CC as ${arg.login} ${arg.pass}...\n`);
    await page.getByLabel('Email').fill(arg.login);
    await page.getByLabel('Password').fill(arg.pass);
    await page.getByRole('button', {name: 'Sign In'}).click()
    await takeScreenshot(page, __filename, 'logged-in');

    log(`Changing Settings for ${app}...\n`);
    await page.getByRole('link', { name: 'Settings', }).click();
    await takeScreenshot(page, __filename, 'settings');
    const url = await page.locator(anchorSelectorURL).getAttribute('href');

    log(`Checking that  ${app} installed in ${url} is running ...\n`);

    log(`Enabling identity Management ...\n`);
    await page.locator('vaadin-select vaadin-input-container div').click();
    await page.getByRole('option', { name: app }).locator('div').nth(2).click();
    await takeScreenshot(page, __filename, 'selected-app');

    // When app is not running, localization button might not be enabled
    let pageApp = await createPage(arg.headless, arg.ignoreHTTPSErrors);
    await waitForServerReady(pageApp, url);
    await takeScreenshot(pageApp, __filename, 'app-running');
    await closePage(pageApp);
    // Button is enabled after app is running, let's see
    await page.getByRole('link', { name: 'Identity Management' }).click();
    await takeScreenshot(page, __filename, 'identity-link-clicked');
    await page.getByRole('button', { name: 'Enable Identity Management' }).click();
    await takeScreenshot(page, __filename, 'identity-enabled');

    log(`Adding Role, Group and User ...\n`);
    await page.getByRole('link', { name: 'Roles' }).click();
    await page.waitForTimeout(2000);
    await page.getByRole('button', { name: 'Create' }).click();
    await takeScreenshot(page, __filename, 'role-form');
    await page.getByLabel('Name').fill(role);
    await page.getByLabel('Description').fill(role);
    await takeScreenshot(page, __filename, 'role-filled');
    await page.getByRole('contentinfo').getByRole('button', { name: 'Create' }).click();
    await takeScreenshot(page, __filename, 'role-created');

    await page.getByRole('link', { name: 'Groups' }).click();
    await page.waitForTimeout(2000);
    await page.getByRole('button', { name: 'Create' }).click();
    await takeScreenshot(page, __filename, 'group-form');
    await page.getByLabel('Name').fill(group);
    await page.locator(checkboxSelectorRole).click();
    await takeScreenshot(page, __filename, 'group-filled');
    await page.getByRole('contentinfo').getByRole('button', { name: 'Create' }).click();
    await takeScreenshot(page, __filename, 'group-created');

    await page.getByRole('link', { name: 'Users' }).click();
    await page.waitForTimeout(2000);
    await page.getByRole('button', { name: 'Create' }).click();
    await takeScreenshot(page, __filename, 'user-form');
    await page.getByLabel('First Name').fill(role);
    await page.getByLabel('Last Name').fill('user');
    await page.getByLabel('E-mail Address').fill(user);
    await page.getByLabel('Password', { exact: true }).fill(role);
    await page.locator(checkboxSelectorGroup).click();
    await takeScreenshot(page, __filename, 'user-filled');
    await page.getByRole('contentinfo').getByRole('button', { name: 'Create' }).click();
    await takeScreenshot(page, __filename, 'user-created');

    log(`Logging in ${app} as ${user} ...\n`);
    pageApp = await createPage(arg.headless, arg.ignoreHTTPSErrors);
    await waitForServerReady(pageApp, url);
    await takeScreenshot(pageApp, __filename, `app-${app}-loaded`);
    await pageApp.getByLabel('Email').fill(user);
    await pageApp.getByLabel('Password').fill(role);
    await pageApp.getByRole('button', {name: 'Sign In'}).click()
    await takeScreenshot(pageApp, __filename, `logged-in-${app}`);
    await expect(pageApp.getByRole('button', { name: 'New order' })).toBeVisible();
    await closePage(pageApp);

    log('Cleaning up...\n');
    try {
        await page.getByRole('link', { name: 'Roles' }).click();
        await page.waitForTimeout(2000);
        await page.getByText(role, { exact: true }).nth(1).click();
        await page.getByRole('button', { name: 'Delete' }).click();
        await page.locator('vaadin-confirm-dialog-overlay').getByRole('button', { name: 'Delete' }).click();
        await page.getByRole('link', { name: 'Groups' }).click();
        await page.waitForTimeout(2000);
        await page.getByText(group, { exact: true }).click();
        await page.getByRole('button', { name: 'Delete' }).click();
        await page.locator('vaadin-confirm-dialog-overlay').getByRole('button', { name: 'Delete' }).click();
        await page.getByRole('link', { name: 'Users' }).click();
        await page.waitForTimeout(2000);
        await page.getByText(user, { exact: true }).click();
        await page.getByRole('button', { name: 'Delete' }).click();
        await page.locator('vaadin-confirm-dialog-overlay').getByRole('button', { name: 'Delete' }).click();
        await page.getByRole('link', { name: 'Settings' }).click();
        await page.waitForTimeout(2000);
        await page.locator('vaadin-grid').getByText('bakery-cc', { exact: true }).click();
        await page.getByLabel('Identity Management').uncheck();
        await page.getByRole('button', { name: 'Disable' }).click();
        await page.getByRole('button', { name: 'Update' }).click();
    } catch (error) {
        err(`Error cleaning up: ${error}\n`);
        await takeScreenshot(page, __filename, 'error-cleaning');
    }
    await closePage(page);
})();
