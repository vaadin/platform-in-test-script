const { expect} = require('@playwright/test');
const fs = require('fs');
const {log, args, createPage, closePage, takeScreenshot, waitForServerReady} = require('./test-utils');


(async () => {
    const arg = args();
    if (!arg.email) {
        log(`Skipping the setup of Control center because of missing --email= parameter\n`)
        process.exit(1);
    }

    const app = `app1`;
    const host = arg.url.replace(/^.*:\/\//, '').replace(/\/.*$/, '');
    const domain = host.replace(/[^.]+\./, '');
    const uri = `${app}.${domain}`;
    const cert = [ domain, uri ].map(a => `${a}.pem`).filter( a => fs.existsSync(a))[0]
    console.log(`Depoying App: ${app} URI: ${uri} Cert: ${cert}`);

    const page = await createPage(arg.headless, arg.ignoreHTTPSErrors);
    await waitForServerReady(page, arg.url);

    await expect(page.getByLabel('Email')).toBeVisible();
    await takeScreenshot(page, 'view-loaded');

    await page.getByLabel('Email').fill(arg.email);
    await page.getByLabel('Password').fill(arg.pass);
    await page.waitForTimeout(500);
    await page.getByRole('button', {name: 'Sign In'}).click()
    log(`Logging in as ${arg.email} ${arg.pass}...\n`);
    await takeScreenshot(page, 'logged-in');

    await page.getByRole('listitem').filter({ hasText: 'Settings'}).click()
    await page.getByRole('button', {name: 'Deploy'}).click()
    await takeScreenshot(page, 'form-opened');

    await page.getByLabel('Application Name', {exact: true}).fill(app)
    await page.getByLabel('Image', {exact: true}).fill('k8sdemos/bakery-cc:latest')
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

    await takeScreenshot(page, 'form-filled');
    await page.getByRole('listitem').filter({ hasText: 'Settings'}).click()

    await expect(await page.getByRole('listitem')
        .filter({ hasText: 'Applications'})
        .textContent()).toEqual('Applications1');

    await takeScreenshot(page, 'application-created');

    await closePage(page);
})();
