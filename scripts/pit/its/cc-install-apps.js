const { chromium } = require('playwright');
const path = require('path');
const sleep = ms => new Promise(r => setTimeout(r, ms));
const { expect } = require('@playwright/test');

const ADMIN_EMAIL = 'john.doe@admin.com';
const ADMIN_PASSWORD = 'adminPassword';

let headless = false, host = 'localhost', port = '8000', hub = false;
process.argv.forEach(a => {
    if (/^--headless/.test(a)) {
        headless = true;
    } else if (/^--ip=/.test(a)) {
        ip = a.split('=')[1];
    } else if (/^--port=/.test(a)) {
        port = a.split('=')[1];
    }
});

(async () => {
    const browser = await chromium.launch({
        headless: headless,
        chromiumSandbox: false
    });
    const context = await browser.newContext({ ignoreHTTPSErrors: true });

    // Open new page
    const page = await context.newPage();
    page.on('console', msg => console.log("> CONSOLE:", (msg.text() + ' - ' + msg.location().url).replace(/\s+/g, ' ')));
    page.on('pageerror', err => console.log("> PAGEERROR:", ('' + err).replace(/\s+/g, ' ')));

    // Go to http://${host}:${port}/
    await page.goto(`http://${host}:${port}/`);

    await page.getByLabel('Email').fill(ADMIN_EMAIL)
    await page.getByLabel('Password', {exact: true}).fill(ADMIN_PASSWORD)
    await page.getByRole('button', {name: 'Sign In'}).click()

    await page.getByRole('listitem').filter({ hasText: 'Settings'}).click()
    await page.getByRole('button', {name: 'Deploy'}).click()

    await page.getByLabel('Application Name', {exact: true}).fill('App1')
    await page.getByLabel('Image', {exact: true}).fill('k8sdemos/bakery-cc:latest')
    await page.getByLabel('Application URI', {exact: true}).locator('input[type="text"]').fill('app1-local.alcala.org')

    await page.getByLabel('Upload').click();
    const fileChooserPromise = page.waitForEvent('filechooser');
    await page.getByText('Browse').click();
    const fileChooser = await fileChooserPromise;
    await fileChooser.setFiles(path.join(__dirname, 'app1-local.alcala.org.pem'));

    fileChooserPromise.then(await page.locator('.detail-layout').getByRole('button', {name: 'Deploy'}).click())

    await page.getByRole('listitem').filter({ hasText: 'Settings'}).click()

    await expect(await page.getByRole('listitem')
        .filter({ hasText: 'Applications'})
        .textContent()).toEqual('Applications1');

    // ---------------------
    await context.close();
    await browser.close();
})();
