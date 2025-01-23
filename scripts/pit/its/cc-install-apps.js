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

    if(process.env.CC_CERT){
      fs.writeFileSync('domain.pem', `${process.env.CC_CERT.replace(/\\n/g, "\n")}\n${process.env.CC_KEY.replace(/\\n/g, "\n")}`);
    }

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

    await page.getByRole('listitem').filter({ hasText: 'Settings'}).click()
    await page.getByRole('button', {name: 'Deploy'}).click()
    await takeScreenshot(page, 'form-opened');

    await page.getByLabel('Application Name', {exact: true}).fill('App1')
    await page.getByLabel('Image', {exact: true}).fill('k8sdemos/bakery-cc:latest')
    await page.getByLabel('Application URI', {exact: true}).locator('input[type="text"]').fill('app1.local.alcala.org')

    const host = url.replace(/^.*:\/\//, '').replace(/\/.*$/, '');
    const domain = host.replace(/.*?\.]/, '');
    const cert = [ domain, host ].map(a => `/tmp/${a}.pem`).filter( a => fs.existsSync(a))[0]
    if (cert) {
        await page.getByLabel('Upload').click();
        const fileChooserPromise = page.waitForEvent('filechooser');
        await page.getByText('Browse').click();
        const fileChooser = await fileChooserPromise;
        await fileChooser.setFiles(cert);
        fileChooserPromise.then(await page.locator('.detail-layout').getByRole('button', {name: 'Deploy'}).click())
    } else {
        await page.getByLabel('Generate').click();
        await page.locator('.detail-layout').getByRole('button', {name: 'Deploy'}).click();
    }

    await takeScreenshot(page, 'form-filled');
    await page.getByRole('listitem').filter({ hasText: 'Settings'}).click()

    await expect(await page.getByRole('listitem')
        .filter({ hasText: 'Applications'})
        .textContent()).toEqual('Applications1');

    await takeScreenshot(page, 'application-created');

    await context.close();
    await browser.close();
})();
