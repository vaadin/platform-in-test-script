const { chromium } = require('playwright');
const path = require('path');
const { expect } = require('@playwright/test');
const fs = require('fs');


let headless = false, port = '8000', url, email, pass='Servantes', ignoreHTTPSErrors = false;
process.argv.forEach(a => {
    if (/^--headless/.test(a)) {
        headless = true;
    } else if (/^--port=/.test(a)) {
        port = a.split('=')[1];
    } else if (/^--url=/.test(a))  {
        url = a.split('=')[1];
    } else if (/^--email=/.test(a)) {
        email = a.split('=')[1];
    } else if (/^--pass=/.test(a)) {
        pass = a.split('=')[1];
    } else if (/^--notls/.test(a)) {
        ignoreHTTPSErrors = true;
    }
});

if (!email) {
    log(`Skipping the setup of Control center because of missing --email= parameter\n`)
    return;
}

const log = s => process.stderr.write(`   ${s}`);
const screenshots = "screenshots.out"
let sscount = 0;
async function takeScreenshot(page, name) {
  const scr = path.basename(__filename);
  const file = `${screenshots}/${scr}-${++sscount}-${name}.png`;
  await page.waitForTimeout(1000);
  await page.screenshot({ path: file });
  log(`Screenshot taken: ${file}\n`);
}

(async () => {
    const browser = await chromium.launch({
        headless: headless,
        chromiumSandbox: false,
        slowMo: 500
    });
    const context = await browser.newContext({ ignoreHTTPSErrors: ignoreHTTPSErrors });

    // Open new page
    const page = await context.newPage();
    page.on('console', msg => console.log("> CONSOLE:", (msg.text() + ' - ' + msg.location().url).replace(/\s+/g, ' ')));
    page.on('pageerror', err => console.log("> PAGEERROR:", ('' + err).replace(/\s+/g, ' ')));

   await page.goto(`${url}`);

    await expect(page.getByLabel('Email')).toBeVisible();
    await takeScreenshot(page, 'view-loaded');

    await page.getByLabel('Email').fill(email);
    await page.getByLabel('Password').fill(pass);
    await page.waitForTimeout(500);
    await page.getByRole('button', {name: 'Sign In'}).click()
    log(`Logging in as ${email} ${pass}...\n`);
    await takeScreenshot(page, 'logged-in');

    await page.locator('vaadin-grid').getByText('App1', { exact: true }).click();
    await page.getByRole('link', { name: 'Roles' }).click();
    await page.getByRole('button', { name: 'Create' }).click();
    await page.getByLabel('Name').fill('ADMIN');
    await page.getByRole('contentinfo').getByRole('button', { name: 'Create' }).click();

    await page.getByRole('link', { name: 'Groups' }).click();
    await page.getByLabel('Name').fill('ADMIN');
    await page.locator('#input-vaadin-checkbox-118').check();
    await page.getByRole('contentinfo').getByRole('button', { name: 'Create' }).click();

    await page.getByRole('link', { name: 'Users' }).click();
    await page.getByRole('button', { name: 'Create' }).click();
    await page.getByLabel('First Name').fill('admin@vaadin.com');
    await page.getByLabel('First Name').fill('Admin');
    await page.getByLabel('Last Name').fill('Vaadin');
    await page.getByLabel('E-mail Address').fill('admin@vaadin.com');
    await page.locator('#input-vaadin-checkbox-250').check();

    await page.getByLabel('Password', { exact: true }).fill('admin');
    await page.getByRole('contentinfo').getByRole('button', { name: 'Create' }).click();
  
    
    // await page.getByLabel('Identity Management').click()
    // await page.locator('vaadin-grid').getByText('App1', { exact: true }).click();
    // await page.getByLabel('Identity Management').check();
    // await page.getByRole('button', { name: 'Update' }).click();

    await page.getByRole('link', { name: 'Users' }).click();
    await page.getByRole('button', { name: 'Create' }).click();
    await page.getByLabel('First Name').fill('admin');
    await page.getByLabel('Last Name').fill('vaadin');
    await page.getByLabel('E-mail Address').fill('admin@vaadin.com');
    await page.getByLabel('Password', { exact: true }).fill('1234....');
    await page.getByRole('contentinfo').getByRole('button', { name: 'Create' })







    // await page.getByRole('contentinfo').getByRole('button', { name: 'Create' }).click();

    // await page.goto(`${url}/app/app1/idm/users`);
    // await page.getByRole('button', {name: 'Create'}).click()

    // await page.getByLabel('First Name').fill(USER_FIRST_NAME)
    // await page.getByLabel('Last Name').fill(USER_LAST_NAME)
    // await page.getByLabel('E-mail Address').fill(USER_EMAIL)
    // await page.getByLabel('Password', { exact: true }).fill(USER_PASSWORD)

    // await page.locator('.detail-layout').getByRole('button', {name: 'Create'}).click()

    // await expect(await page.getByRole('listitem')
    //     .filter({ hasText: 'Users'})
    //     .textContent()).toEqual('Users1');

    // await page.goto(`https://app1-local.alcala.org`);
    // await page.getByLabel('Email').fill(USER_EMAIL)
    // await page.getByLabel('Password', {exact: true}).fill(USER_PASSWORD)
    // await page.getByRole('button', {name: 'Sign In'}).click()

    // await expect(page).toHaveURL(new RegExp('^https://app1-local.alcala.org'));

    // await page.goto(`http://${host}:${port}/app/app1/idm/users`);
    // await page.getByText([USER_FIRST_NAME, USER_LAST_NAME].join(' ')).click()
    // await page.getByRole('button', {name: 'Delete'}).click()
    // await sleep(1000)
    // await page.getByRole('button', {name: 'Delete'}).click()
    // await sleep(1000)
    // await expect(await page.getByRole('listitem')
    //     .filter({ hasText: 'Users'})
    //     .textContent()).toEqual('Users0');

    // ---------------------
    await context.close();
    await browser.close();
})();
