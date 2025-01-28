const { expect} = require('@playwright/test');
const fs = require('fs');
const {log, args, createPage, closePage, takeScreenshot, waitForServerReady} = require('./test-utils');


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

    log(`Logging in as ${arg.login} ${arg.pass}...\n`);
    await page.getByLabel('Email').fill(arg.login);
    await page.getByLabel('Password').fill(arg.pass);
    await page.getByRole('button', {name: 'Sign In'}).click()
    await takeScreenshot(page, __filename, 'logged-in');

    await page.getByRole('link', { name: 'Settings', }).click();
    await takeScreenshot(page, __filename, 'settings');
    const url = await page.locator(anchorSelectorURL).getAttribute('href');
    log(`App: ${app} installed in: ${url}\n`);

    await page.locator('vaadin-select vaadin-input-container div').click();
    await page.getByRole('option', { name: 'bakery-cc' }).locator('div').nth(2).click();
    await takeScreenshot(page, __filename, 'selected-app');
    await page.getByRole('link', { name: 'Identity Management' }).click();
    await page.getByRole('button', { name: 'Enable Identity Management' }).click();
    await takeScreenshot(page, __filename, 'app-updated');
    await takeScreenshot(page, __filename, 'identity-management-enabled');

    await page.getByRole('link', { name: 'Roles' }).click();
    await page.getByRole('button', { name: 'Create' }).click();
    await page.getByLabel('Name').fill(role);
    await page.getByLabel('Description').fill(role);
    await takeScreenshot(page, __filename, 'role-filled');
    await page.getByRole('contentinfo').getByRole('button', { name: 'Create' }).click();
    await takeScreenshot(page, __filename, 'role-created');

    await page.getByRole('link', { name: 'Groups' }).click();
    await page.getByRole('button', { name: 'Create' }).click();
    await page.getByLabel('Name').fill(group);
    await page.locator(checkboxSelectorRole).click();
    await takeScreenshot(page, __filename, 'group-filled');
    await page.getByRole('contentinfo').getByRole('button', { name: 'Create' }).click();
    await takeScreenshot(page, __filename, 'group-created');

    await page.getByRole('link', { name: 'Users' }).click();
    await page.getByRole('button', { name: 'Create' }).click();
    await page.getByLabel('First Name').fill(role);
    await page.getByLabel('Last Name').fill('user');
    await page.getByLabel('E-mail Address').fill(user);
    await page.getByLabel('Password', { exact: true }).fill(role);
    await page.locator(checkboxSelectorGroup).click();
    await takeScreenshot(page, __filename, 'user-filled');
    await page.getByRole('contentinfo').getByRole('button', { name: 'Create' }).click();
    await takeScreenshot(page, __filename, 'user-created');

    await page.goto(url);
    await takeScreenshot(page, __filename, `app-${app}-loaded`);

    log(`Logging in ${app} as ${user} ...\n`);
    await page.getByLabel('Email').fill(user);
    await page.getByLabel('Password').fill(role);
    await page.getByRole('button', {name: 'Sign In'}).click()
    await takeScreenshot(page, __filename, `logged-in-${app}`);
    await expect(page.getByRole('button', { name: 'New order' })).toBeVisible();

    await closePage(page);
})();
