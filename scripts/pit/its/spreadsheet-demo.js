const { chromium } = require('playwright');
const { log, args, closePage, takeScreenshot, waitForServerReady } = require('./test-utils');

(async () => {
    const arg = args();

    log('Creating browser with special headers for Spreadsheet demo');
    const browser = await chromium.launch({
        headless: arg.headless
    });
    const context = await browser.newContext({
        extraHTTPHeaders: {
            'X-AppUpdate': 'FOO'
        }
    });
    const sleep = ms => new Promise(r => setTimeout(r, ms));

    const page = await context.newPage();
    page.on('console', msg => console.log("> CONSOLE:", (msg.text() + ' - ' + msg.location().url).replace(/\s+/g, ' ')));
    page.on('pageerror', err => console.log("> PAGEERROR:", ('' + err).replace(/\s+/g, ' ')));

    await waitForServerReady(page, arg.url);
    await takeScreenshot(page, __filename, 'page-loaded');

    await page.evaluate(() => {
        window.localStorage.setItem("vaadin.live-reload.dismissedNotifications","liveReloadUnavailable,preserveOnRefreshWarning")
        window.location.reload();
    });

    log('Testing Basic functionality');
    await page.getByRole('link', { name: 'Basic functionality' }).click();
    await page.waitForURL(`${arg.url}/demo/basic`);
    await takeScreenshot(page, __filename, 'basic-functionality');

    await page.locator('.col2').first().click();
    await sleep(100);
    const c = await page.getByText('SIMPLE MONTHLY BUDGET').count();
    if (!c) throw new Error('Text not found');

    log('Testing Collaborative features');
    await page.getByRole('link', { name: 'Collaborative features' }).click();
    await page.waitForURL(`${arg.url}/demo/collaborative`);
    await takeScreenshot(page, __filename, 'collaborative-features');

    await page.locator('vaadin-spreadsheet div:has-text("Loan calculator")').nth(2).click();
    await page.getByText('5.00%').dblclick();
    await page.locator('#cellinput').click();
    await page.locator('#cellinput').fill('0.03');
    await page.locator('#cellinput').press('Enter');
    await page.getByText('$10,315.49');
    await sleep(100);
    await page.keyboard.press('Enter');
    await sleep(100);
    await page.locator('#cellinput').click();
    await page.locator('#cellinput').fill('20');
    await page.locator('#cellinput').press('Enter');
    await page.getByText('$13,310.34').click();
    await sleep(100);
    await takeScreenshot(page, __filename, 'loan-calculator-tested');

    log('Testing Grouping features');
    await page.getByRole('link', { name: 'Grouping' }).click();
    await page.waitForURL(`${arg.url}/demo/grouping`);
    await page.getByText('+').nth(3).click();
    await page.getByText('December').click();
    await takeScreenshot(page, __filename, 'grouping-tested');

    log('Testing Report mode');
    await page.getByRole('link', { name: 'Report mode' }).click();
    await page.waitForURL(`${arg.url}/demo/reportMode`);
    await page.getByText('547 Demo Suites #85').click();
    await takeScreenshot(page, __filename, 'report-mode-tested');

    log('Testing Simple invoice');
    await page.getByRole('link', { name: 'Simple invoice' }).click();
    await page.waitForURL(`${arg.url}/demo/simpleInvoice`);
    await page.getByText('547 Demo Suites #85').click();
    await takeScreenshot(page, __filename, 'simple-invoice-tested');

    log('Spreadsheet demo tested successfully');
    await context.close();
    await browser.close();
})();
