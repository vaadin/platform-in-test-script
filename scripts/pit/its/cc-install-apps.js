const { chromium } = require('playwright');
const path = require('path');
const { expect } = require('@playwright/test');
const fs = require('fs');

const ADMIN_EMAIL = 'john.doe@admin.com';
const ADMIN_PASSWORD = 'adminPassword';



let headless = false, port = '8000', url, email, pass='Servantes', ignoreHTTPSErrors = false;
process.argv.forEach(a => {
    if (/^--headless/.test(a)) {
        headless = true;
    } else if (/^--port=/.test(a)) {
        port = a.split('=')[1];
    } else if (/^--url=/.test(a)) {
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

(async () => {
    const browser = await chromium.launch({
        headless: headless,
        chromiumSandbox: false,
        slowMo: 500
    });
    const context = await browser.newContext({ ignoreHTTPSErrors: ignoreHTTPSErrors });

    fs.writeFileSync('domain.pem', `${process.env.CC_CERT.replace(/\\n/g, "\n")}\n${process.env.CC_KEY.replace(/\\n/g, "\n")}`);

    // Open new page
    const page = await context.newPage();
    page.on('console', msg => console.log("> CONSOLE:", (msg.text() + ' - ' + msg.location().url).replace(/\s+/g, ' ')));
    page.on('pageerror', err => console.log("> PAGEERROR:", ('' + err).replace(/\s+/g, ' ')));

    await page.goto(`${url}`);

    await expect(page.getByLabel('Email')).toBeVisible();

    await page.getByLabel('Email').fill(email);
    await page.getByLabel('Password').fill(pass);
    await page.waitForTimeout(500);
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
    await fileChooser.setFiles('domain.pem');

    fileChooserPromise.then(await page.locator('.detail-layout').getByRole('button', {name: 'Deploy'}).click())

    await page.getByRole('listitem').filter({ hasText: 'Settings'}).click()

    await expect(await page.getByRole('listitem')
        .filter({ hasText: 'Applications'})
        .textContent()).toEqual('Applications1');

    console.log(`Application app1 deployed successfully`);
    // ---------------------
    await context.close();
    await browser.close();
})();
