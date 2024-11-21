const {chromium} = require('playwright');
const sleep = ms => new Promise(r => setTimeout(r, ms));
const path = require('path');
const {expect} = require('@playwright/test');

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
    const context = await browser.newContext({ignoreHTTPSErrors: true});

    // Open new page
    const page = await context.newPage();
    page.on('console', msg => console.log("> CONSOLE:", (msg.text() + ' - ' + msg.location().url).replace(/\s+/g, ' ')));
    page.on('pageerror', err => console.log("> PAGEERROR:", ('' + err).replace(/\s+/g, ' ')));

    // Go to http://${host}:${port}/
    await page.goto(`http://${host}:${port}/`);

    await page.getByLabel('Email').fill(ADMIN_EMAIL)
    await page.getByLabel('Password', {exact: true}).fill(ADMIN_PASSWORD)
    await page.getByRole('button', {name: 'Sign In'}).click()

    await page.goto(`http://${host}:${port}/settings/apps/app1`);

    const locOpt = page.getByLabel('Localization').click();
    if(await !page.getByLabel('Localization').isChecked()){
        await page.getByLabel('Localization').click({timeout:60000})
    }

    await page.getByRole('button', {name: 'Update'}).click()

    await page.goto(`http://${host}:${port}/app/app1/i18n/translations`);

    await page.getByRole('menuitem').click()
    await page.getByText('Upload translations').click()


    const fileChooserPromise = page.waitForEvent('filechooser');
    await page.getByText('Upload Files...').click();
    const fileChooser = await fileChooserPromise;
    await fileChooser.setFiles(path.join(__dirname, 'translations.properties'));
    await page.getByLabel('I understand that this will replace all corresponding data.').check()
    await page.getByRole('button', {name: 'Replace data'}).click()

    await page.getByText('Hello anonymous!').click();
    await page.locator('vaadin-grid-cell-content').getByRole('textbox').fill('Test');

    await page.getByText('Say hello').click();
    await page.locator('vaadin-grid-cell-content').getByRole('textbox').fill('Say bonjour');
    await page.locator('.confirm-button').click();

    expect(page.getByText('Hello anonymous!')).toBeVisible()
    expect(page.locator('vaadin-grid-cell-content').filter({ hasText: 'Say bonjour' })).toBeVisible()

    // ---------------------
    await context.close();
    await browser.close();
})();
