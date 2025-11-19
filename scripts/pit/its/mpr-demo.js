const { chromium } = require('playwright');
const { log, args, closePage, takeScreenshot, waitForServerReady, dismissDevmode } = require('./test-utils');

(async () => {
    const arg = args();

    log('Creating browser with special headers for MPR demo');
    const browser = await chromium.launch({
        headless: arg.headless
    });
    const context = await browser.newContext({
        extraHTTPHeaders: {
            'X-AppUpdate': 'FOO'
        }
    });
    const page = await context.newPage();
    page.on('console', msg => console.log("> CONSOLE:", (msg.text() + ' - ' + msg.location().url).replace(/\s+/g, ' ')));
    page.on('pageerror', err => console.log("> PAGEERROR:", ('' + err).replace(/\s+/g, ' ')));

    await waitForServerReady(page, arg.url);
    await takeScreenshot(page, __filename, 'page-loaded');

    await page.evaluate(() => {
        window.localStorage.setItem("vaadin.live-reload.dismissedNotifications","liveReloadUnavailable,preserveOnRefreshWarning")
        window.location.reload();
    });

    await page.locator('vaadin-notification-card[role="alert"]:has-text("Hello") div').nth(1).click();
    await takeScreenshot(page, __filename, 'notification-dismissed');

    log('Testing Spreadsheet view');
    await page.getByRole('link', { name: 'Spreadsheet' }).click();
    await page.waitForURL(`${arg.url}spreadsheet`);
    await takeScreenshot(page, __filename, 'spreadsheet-loaded');

    await page.getByText('90', { exact: true }).click();
    await page.locator('div:nth-child(59)').dblclick();

    await page.locator('#cellinput').click();
    await page.locator('#cellinput').fill('=B4*3');
    await page.locator('#cellinput').press('Enter');
    await page.getByText('270').click();
    await takeScreenshot(page, __filename, 'spreadsheet-formula-tested');

    log('Testing Tree view');
    await page.getByRole('link', { name: 'Tree' }).click();
    await page.waitForURL(`${arg.url}tree`);
    await takeScreenshot(page, __filename, 'tree-loaded');

    await page.locator('span.v-tree8-expander').nth(0).click()
    await page.locator('span.v-tree8-expander').nth(1).click()
    await takeScreenshot(page, __filename, 'tree-expanded');

    log('Testing Video view');
    await page.getByRole('link', { name: 'Video' }).click();
    await page.waitForURL(`${arg.url}video`);
    await takeScreenshot(page, __filename, 'video-loaded');

    log('Testing Legacy view');
    await page.getByRole('link', { name: 'Legacy' }).click();
    await page.waitForURL(`${arg.url}legacy`);
    await page.getByText('Here we are!').click();
    await takeScreenshot(page, __filename, 'legacy-tested');

    log('Testing navigation back to home');
    await page.locator('vaadin-vertical-layout:has-text("SpreadsheetTreeVideoLegacy") path').click();
    await page.waitForURL(`${arg.url}`);
    await takeScreenshot(page, __filename, 'back-to-home');

    log('MPR demo tested successfully');
    await context.close();
    await browser.close();
})();
