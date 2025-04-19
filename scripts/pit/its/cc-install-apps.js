const { expect} = require('@playwright/test');
const fs = require('fs');
const {log, args, run, createPage, closePage, takeScreenshot, waitForServerReady} = require('./test-utils');

const arg = args();
let count = 0;

async function installApp(app, page) {
    const host = arg.url.replace(/^.*:\/\//, '').replace(/\/.*$/, '');
    const domain = host.replace(/[^.]+\./, '');
    const uri = `${app}.${domain}`;
    const cert = [ domain, uri ].map(a => `${a}.pem`).filter( a => fs.existsSync(a))[0]
    const tag = arg.tag || 'latest';
    const registry = arg.registry || 'k8sdemos';
    console.log(`Installing App: ${app} URI: ${uri} Cert: ${cert}`);

    await page.getByRole('listitem').filter({ hasText: 'Settings'}).click()
    await page.getByRole('button', {name: /Create|New/}).click()
    await takeScreenshot(page, __filename, `form-opened-${app}`);

    await page.getByLabel('Application Name', {exact: true}).fill(app)
    await page.getByLabel('Image', {exact: true}).fill(`${registry}/${app}:${tag}`)
    if (arg.secret) {
        await page.getByLabel('Needs Pull Secret').check();
        await page.getByPlaceholder('Image Pull Secret').locator('input').fill(arg.secret);
        await takeScreenshot(page, __filename, `form-with-secret-${app}`);
    }
    await page.getByLabel('Startup Delay (secs)').fill(process.env.GITHUB_ACTIONS ? '90' : '90');
    await page.getByLabel('Application URI', {exact: true}).locator('input[type="text"]').fill(uri)
    if (cert) {
        log(`Uploading certificate ${cert} for ${app}...\n`);
        await page.getByLabel('Upload').click();
        const fileChooserPromise = page.waitForEvent('filechooser');
        await page.getByText('Browse').click();
        const fileChooser = await fileChooserPromise;
        await fileChooser.setFiles(cert);
        await takeScreenshot(page, __filename, `form-filled-${app}`);
        await page.locator('.detail-layout').getByRole('button', {name: 'Deploy'}).click();
    } else {
        log(`No certificate found for ${app}...\n`);
        log(`No certificate found for ${app}\n`);
        run(`pwd`);
        run(`ls -l`);
        await page.getByLabel('Generate').click();
        await takeScreenshot(page, __filename, `form-filled-${app}`);
        await page.locator('.detail-layout').getByRole('button', {name: 'Deploy'}).click();
    }

    await page.getByRole('listitem').filter({ hasText: 'Settings'}).click()
    await takeScreenshot(page, __filename, `form-saved-${app}`);

    await expect(page.locator('vaadin-grid').getByText(app, { exact: true })).toBeVisible();
    await expect(await page.getByRole('listitem').filter({ hasText: 'Applications'})
          .textContent()).toEqual(`Applications${++count}`);
}

(async () => {
    if (!arg.login) {
        log(`Skipping the setup of Control center because of missing --email= parameter\n`)
        process.exit(1);
    }
    const page = await createPage(arg.headless, arg.ignoreHTTPSErrors);
    await waitForServerReady(page, arg.url);
    await takeScreenshot(page, __filename, 'view-loaded');

    log(`Logging in as ${arg.login} ${arg.pass}...\n`);
    await page.getByLabel('Email').fill(arg.login);
    await page.getByLabel('Password').fill(arg.pass);
    await page.waitForTimeout(500);
    await page.getByRole('button', {name: 'Sign In'}).click()
    await takeScreenshot(page, __filename, 'logged-in');

    for (const app of ['bakery-cc', 'bakery']) {
        await installApp(app, page);
    }

    await takeScreenshot(page, __filename, 'installed-apps');
    log(`Waiting for 2 applications to be available...\n`);
    await page.waitForTimeout(80000);
    await page.reload();
    await takeScreenshot(page, __filename, 'waiting for apps');
    const selector = 'vaadin-grid-cell-content span[theme="badge success"]';
    const startTime = Date.now();

    await expect(page.locator(selector).nth(0)).toBeVisible({ timeout: 280000 });
    const firstAppTime = (Date.now() - startTime) / 1000;
    await takeScreenshot(page, __filename, 'app-1-available');
    log(`First application is available after ${firstAppTime.toFixed(2)} seconds\n`);

    await expect(page.locator(selector).nth(1)).toBeVisible({ timeout: 280000 });
    const secondAppTime = (Date.now() - startTime) / 1000;
    await takeScreenshot(page, __filename, 'app-2-available');
    log(`Second application is available after ${secondAppTime.toFixed(2)} seconds\n`);

    await closePage(page);
})();
