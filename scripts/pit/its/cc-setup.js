const {chromium} = require('playwright');
const { expect } = require('@playwright/test');
const { exec } = require('child_process');
const promisify = require('util').promisify;

const log = s => process.stderr.write(`   ${s}`);
const run = async cmd => (await promisify(exec)(cmd)).stdout;

let headless = false, port = '8000', url, email, tmppass, pass='Servantes', ignoreHTTPSErrors = false;
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
    } else if (/^--tmppass=/.test(a)) {
        tmppass = a.split('=')[1];
    } else if (/^--notls/.test(a)) {
        ignoreHTTPSErrors = true;
    } 
});

if (!url) {
    url = `http://${host}:${port}/`;
}

if (!email) {
    log(`Skipping the setup of Control center because of missing --email= parameter\n`)
    return;
}

(async () => {
    if (!tmppass) {
        tmppass = await run(`kubectl -n control-center get secret control-center-user -o go-template="{{ .data.password | base64decode | println }}"`);
    }
    const browser = await chromium.launch({
        headless: headless,
        chromiumSandbox: false,
        slowMo: 500
    });
    const context = await browser.newContext({ ignoreHTTPSErrors: ignoreHTTPSErrors });

    const page = await context.newPage();
    page.on('console', msg => console.log("> CONSOLE:", (msg.text() + ' - ' + msg.location().url).replace(/\s+/g, ' ')));
    page.on('pageerror', err => console.log("> PAGEERROR:", ('' + err).replace(/\s+/g, ' ')));

    await page.goto(`${url}`);

    await expect(page.getByLabel('Email')).toBeVisible();

    await page.getByLabel('Email').fill(email);
    await page.getByLabel('Password').fill(tmppass);
    await page.waitForTimeout(500);
    await page.getByRole('button', {name: 'Sign In'}).click()

    console.log(email, tmppass, pass)

    await page.waitForTimeout(1000);

    await page.getByLabel('New Password').fill(pass);
    await page.getByLabel('Confirm Password').fill(pass);
    await page.waitForTimeout(500);
    await page.getByRole('button', { name: 'Submit' }).click();

    await page.getByLabel('First Name').fill(email);
    await page.getByLabel('Last Name').fill(email);
    await page.waitForTimeout(500);
    await page.getByRole('button', { name: 'Submit' }).click();
    await page.waitForTimeout(500);
    await page.getByRole('button', { name: 'Manage applications' }).click();
    await page.waitForTimeout(500);

    await expect(page.getByRole('heading', { name: 'Applications' })).toBeVisible();

    console.log(`User ${email} confgigured with password ${pass}`);
  
    await context.close();
    await browser.close();
})();
