const {chromium} = require('playwright');
const { expect } = require('@playwright/test');
const { exec } = require('child_process');
const promisify = require('util').promisify;

const log = s => process.stderr.write(`   ${s}`);
const run = async cmd => (await promisify(exec)(cmd)).stdout;

let headless = false, host = 'localhost', port = '8000', url, email, pass, newpass='Servantes';
process.argv.forEach(a => {
    if (/^--headless/.test(a)) {
        headless = true;
    } else if (/^--ip=/.test(a)) {
        ip = a.split('=')[1];
    } else if (/^--port=/.test(a)) {
        port = a.split('=')[1];
    } else if (/^--url=/.test(a)) {
        url = a.split('=')[1];
    } else if (/^--email=/.test(a)) {
        email = a.split('=')[1];
    } else if (/^--pass=/.test(a)) {
        pass = a.split('=')[1];
    } else if (/^--newpass=/.test(a)) {
        newpass = a.split('=')[1];
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
    if (!pass) {
        pass = await run(`kubectl -n control-center get secret control-center-user -o go-template="{{ .data.password | base64decode | println }}"`);
    }
    const browser = await chromium.launch({
        headless: headless,
        chromiumSandbox: false,
        slowMo: 50
    });
    const context = await browser.newContext();

    const page = await context.newPage();
    page.on('console', msg => console.log("> CONSOLE:", (msg.text() + ' - ' + msg.location().url).replace(/\s+/g, ' ')));
    page.on('pageerror', err => console.log("> PAGEERROR:", ('' + err).replace(/\s+/g, ' ')));

    await page.goto(`${url}`);

    await expect(page.getByLabel('Email')).toBeVisible();

    await page.getByLabel('Email').fill(email);
    await page.getByLabel('Password').fill(pass);
    await page.waitForTimeout(500);
    await page.getByRole('button', {name: 'Sign In'}).click()

    console.log(email, pass, newpass)

    await page.waitForTimeout(5000);

    if (await page.getByRole('paragraph', {hasText: 'Invalid'}).waitFor({ timeout: 1000 }).catch(() => false).then(() => true)) {
        throw new Error(`Incorrect authentication for ${email}`);
    }

    await page.getByLabel('New Password').fill('cc-vaadin');
    await page.getByLabel('Confirm Password').fill('cc-vaadin');
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
  
    await context.close();
    await browser.close();
})();
