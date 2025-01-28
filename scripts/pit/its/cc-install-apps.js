const { expect} = require('@playwright/test');
const fs = require('fs');
const {log, args, createPage, closePage, takeScreenshot, waitForServerReady} = require('./test-utils');

const arg = args();
let count = 0;

async function installApp(app, page) {
    const host = arg.url.replace(/^.*:\/\//, '').replace(/\/.*$/, '');
    const domain = host.replace(/[^.]+\./, '');
    const uri = `${app}.${domain}`;
    const cert = [ domain, uri ].map(a => `${a}.pem`).filter( a => fs.existsSync(a))[0]
    console.log(`Installing App: ${app} URI: ${uri} Cert: ${cert}`);

    await takeScreenshot(page, __filename, `page-loaded-${app}`);

    await page.getByRole('listitem').filter({ hasText: 'Settings'}).click()
    await page.getByRole('button', {name: 'Deploy'}).click()
    await takeScreenshot(page, __filename, `form-opened-${app}`);

    await page.getByLabel('Application Name', {exact: true}).fill(app)
    await page.getByLabel('Image', {exact: true}).fill(`k8sdemos/${app}:latest`)
    await page.getByLabel('Application URI', {exact: true}).locator('input[type="text"]').fill(uri)
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

    await takeScreenshot(page, __filename, `form-filled-${app}`);

    await page.getByRole('listitem').filter({ hasText: 'Settings'}).click()

    await takeScreenshot(page, __filename, `application-created-${app}`);

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

    log(`Waiting for the applications to be available...\n`);
    const selector = 'vaadin-grid-cell-content span[theme="badge success"]';
    await expect(page.locator(selector).nth(0)).toBeVisible({ timeout: 180000 });
    await expect(page.locator(selector).nth(1)).toBeVisible({ timeout: 180000 });

    await closePage(page);
})();
