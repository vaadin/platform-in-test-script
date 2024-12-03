const { chromium } = require('playwright');
const sleep = ms => new Promise(r => setTimeout(r, ms));
const { expect } = require('@playwright/test');

const ADMIN_EMAIL = 'john.doe@admin.com';
const ADMIN_PASSWORD = 'adminPassword';

const USER_EMAIL = 'foo@bar.com';
const USER_PASSWORD = 'password';
const USER_FIRST_NAME = 'foo';
const USER_LAST_NAME = 'bar';

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

    await page.goto(`http://${host}:${port}/settings/apps/app1`);
    await page.getByLabel('Identity Management').click()
    await page.getByRole('button', {name: 'Update'}).click()

    await page.goto(`http://${host}:${port}/app/app1/idm/users`);
    await page.getByRole('button', {name: 'Create'}).click()

    await page.getByLabel('First Name').fill(USER_FIRST_NAME)
    await page.getByLabel('Last Name').fill(USER_LAST_NAME)
    await page.getByLabel('E-mail Address').fill(USER_EMAIL)
    await page.getByLabel('Password', { exact: true }).fill(USER_PASSWORD)

    await page.locator('.detail-layout').getByRole('button', {name: 'Create'}).click()

    await expect(await page.getByRole('listitem')
        .filter({ hasText: 'Users'})
        .textContent()).toEqual('Users1');

    await page.goto(`https://app1-local.alcala.org`);
    await page.getByLabel('Email').fill(USER_EMAIL)
    await page.getByLabel('Password', {exact: true}).fill(USER_PASSWORD)
    await page.getByRole('button', {name: 'Sign In'}).click()

    await expect(page).toHaveURL(new RegExp('^https://app1-local.alcala.org'));

    await page.goto(`http://${host}:${port}/app/app1/idm/users`);
    await page.getByText([USER_FIRST_NAME, USER_LAST_NAME].join(' ')).click()
    await page.getByRole('button', {name: 'Delete'}).click()
    await sleep(1000)
    await page.getByRole('button', {name: 'Delete'}).click()
    await sleep(1000)
    await expect(await page.getByRole('listitem')
        .filter({ hasText: 'Users'})
        .textContent()).toEqual('Users0');

    // ---------------------
    await context.close();
    await browser.close();
})();
