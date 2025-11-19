const { expect } = require('@playwright/test');
const { log, args, createPage, closePage, takeScreenshot, waitForServerReady, dismissDevmode } = require('./test-utils');

(async () => {
    const arg = args();

    const page = await createPage(arg.headless);

    await waitForServerReady(page, arg.url);

    // Dismiss dev mode notification if present
    await dismissDevmode(page);
    await takeScreenshot(page, __filename, 'page-loaded');

    await page.getByLabel('Username').click();
    await page.getByLabel('Username').fill('admin');
    await page.getByLabel('Username').press('Tab');
    await page.getByLabel('Password', { exact: true }).fill('admin');
    await page.getByRole('button', { name: 'Log in' }).click();
    await takeScreenshot(page, __filename, 'logged-in');

    await page.getByRole('button', { name: 'New product' }).waitFor({state: "visible"});
    await page.getByRole('button', { name: 'New product' }).click();
    await page.waitForURL(`${arg.url.replace(/\/$/, '')}/Inventory/new`);
    await takeScreenshot(page, __filename, 'new-product-form');

    await page.getByLabel('Product name', { exact: true }).waitFor({state: "visible"});
    await page.getByLabel('Product name', { exact: true }).click();
    await page.getByLabel('Product name', { exact: true }).fill('foo');
    await page.getByLabel('Price', { exact: true }).click();
    await page.getByLabel('Price', { exact: true }).fill('40.00');
    await page.getByLabel('In stock').click();
    await page.getByLabel('In stock').fill('50');

    await page.getByLabel('Romance').check();
    await page.getByRole('button', { name: 'Save' }).locator('div').click();
    await page.locator('text=foo created').textContent();
    await takeScreenshot(page, __filename, 'product-created');

    await page.getByRole('link', { name: 'Admin' }).waitFor({state: "visible"});
    await page.getByRole('link', { name: 'Admin' }).click();
    await takeScreenshot(page, __filename, 'admin-page');

    await page.getByRole('button', { name: 'Add New Category' }).locator('span').nth(1).click();
    await page.locator('vaadin-text-field').first().waitFor({state: "visible"});

    await page.waitForTimeout(1000);
    const c = (await page.locator('vaadin-text-field').all()).length - 1;
    log(`Found ${c} input elements`);
    await page.locator('input').nth(c).click()
    await page.locator('input').nth(c).fill('BBBB');
    await page.locator('input').nth(c).press('Enter');
    await takeScreenshot(page, __filename, 'category-added');

    await closePage(page);
})();
