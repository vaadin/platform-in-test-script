const { expect} = require('@playwright/test');
const fs = require('fs');
const {log, args, run, createPage, closePage, takeScreenshot, waitForServerReady} = require('./test-utils');

const arg = args();
let count = 0;
const gracePeriodSecs = process.env.FAST ? 20: 90;
const waitForReadyMsecs = 185000;

async function installApp(app, page) {
    const host = arg.url.replace(/^.*:\/\//, '').replace(/\/.*$/, '');
    const domain = host.replace(/[^.]+\./, '');
    const uri = `${app}.${domain}`;
    const cert = [ domain, uri ].map(a => `${a}.pem`).filter( a => fs.existsSync(a))[0]
    const tag = arg.tag || 'latest';
    const registry = arg.registry || 'k8sdemos';
    log(`Installing App: ${app} URI: ${uri} Cert: ${cert} Img: ${registry}/${app}:${tag}`);

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
    await page.getByLabel('Startup Delay (secs)').fill(`${gracePeriodSecs}`);

    if (/bakery/.test(app)) {
        await page.getByRole('button', {name: 'Environment Variable'}).click();
        await takeScreenshot(page, __filename, `env-dialog-opened-${app}`);
        const envDialog = page.getByRole('dialog', { name: 'Environment Variables' });
        await envDialog.getByPlaceholder('Name').locator('input').fill('SHOW_INFO');
        await envDialog.getByPlaceholder('Value').locator('input').fill('true');
        await takeScreenshot(page, __filename, `env-dialog-filled-${app}`);
        await envDialog.getByLabel("Add").click();
        await envDialog.getByLabel("Close").click();
    }

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

    const apps = ['cc-starter', 'bakery-cc', 'bakery'];
    for (const app of apps) {
        await installApp(app, page);
    }

    await takeScreenshot(page, __filename, 'installed-apps');
    const startTime = Date.now();
    log(`Giving a grace period of ${gracePeriodSecs} secs to wait for ${apps.length} apps to be avalable ...\n`);
    await page.waitForTimeout(gracePeriodSecs * 1000);
    await page.reload();
    log(`Waiting for ${apps.length} applications to be available in dashboard ...\n`);
    await takeScreenshot(page, __filename, 'waiting for apps');

    const selector = 'vaadin-grid-cell-content span[theme="badge success"]';

    for (let i = 0; i < apps.length; i++) {
        await expect(page.locator(selector).nth(i)).toBeVisible({ timeout: waitForReadyMsecs });
        const firstAppTime = (Date.now() - startTime) / 1000;
        await takeScreenshot(page, __filename, 'app-1-available');
        log(`application ${i + 1} is available after ${firstAppTime.toFixed(2)} seconds\n`);
    }

    await closePage(page);
})();
