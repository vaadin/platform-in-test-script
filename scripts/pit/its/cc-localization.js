const { expect } = require('@playwright/test');
const fs = require('fs');
const { log, err, args, warn, run, createPage, closePage, takeScreenshot, waitForServerReady } = require('./test-utils');
const { assert } = require('console');

(async () => {
    const arg = args();
    if (!arg.login) {
        log(`Skipping the setup of Control center because of missing --email= parameter\n`)
        process.exit(1);
    }
    const app = `bakery-cc`;
    const downloadsDir = './downloads';
    const propsFile = 'translations.properties';
    const appTitle = 'Panaderia';
    const keyTitle = /^!en(-..)?: app.title$/;

    const page = await createPage(arg.headless, arg.ignoreHTTPSErrors);
    await waitForServerReady(page, arg.url, arg);

    await expect(page.getByLabel('Email')).toBeVisible();
    await takeScreenshot(page, arg, __filename, 'view-loaded');

    log(`Logging in CC as ${arg.login} ${arg.pass}...\n`);
    await page.getByLabel('Email').fill(arg.login);
    await page.getByLabel('Password').fill(arg.pass);
    await page.getByRole('button', { name: 'Sign In' }).click()
    await takeScreenshot(page, arg, __filename, 'logged-in');

    log(`Changing Settings for ${app}...\n`);
    await page.getByRole('link', { name: 'Settings', }).click();
    await takeScreenshot(page, arg, __filename, 'settings');
    const anchorSelectorURL = `//vaadin-grid-cell-content[.//span[normalize-space(text())="${app}"]]//a`;
    const url = await page.locator(anchorSelectorURL).getAttribute('href');
    let previewUrl = url + '?i18n-preview=enable';

    log(`Checking that  ${app} installed in ${url} is running ...\n`);
    // When app is not running, localization cannot be enabled
    const pageApp = await createPage(arg.headless, arg.ignoreHTTPSErrors);
    await waitForServerReady(pageApp, url, arg);
    await takeScreenshot(pageApp, arg, __filename, 'app-running');

    log(`Testing that preview page: ${previewUrl} shows ${keyTitle} \n`);
    await pageApp.goto(previewUrl);
    await takeScreenshot(pageApp, arg, __filename, 'app-preview-before-localization');
    await expect(pageApp.getByText(keyTitle, { exact: true })).toBeVisible();

    log(`Enabling localization and uploading keys ...\n`);
    await page.bringToFront();
    await page.locator('vaadin-select vaadin-input-container div').click();
    await page.getByRole('option', { name: app }).locator('div').nth(2).click();
    await takeScreenshot(page, arg, __filename, 'selected-app');

    await page.getByRole('link', { name: 'Localization' }).click();
    await page.getByRole('button', { name: 'Enable Localization' }).click();
    await takeScreenshot(page, arg, __filename, 'localization-enabled');

    fs.writeFileSync(propsFile, 'app.title=Bakery\n');
    await page.getByLabel('Manage translations').locator('svg').click();
    await page.getByText('Upload translations').click();
    await page.getByLabel('I understand that this will').check();
    const fileChooserPromise = page.waitForEvent('filechooser');
    await page.getByRole('button', { name: 'Upload Files...' }).click();
    const fileChooser = await fileChooserPromise;
    await fileChooser.setFiles(propsFile);
    await page.getByRole('button', { name: 'Replace data' }).click();
    fs.unlinkSync(propsFile);
    await takeScreenshot(page, arg, __filename, 'localization-loaded');

    log(`Changing app.tittle from Bakery to ${appTitle} ...\n`);
    await page.getByText('Bakery', { exact: true }).click();
    await page.locator('vaadin-text-area.inline textarea').fill(appTitle);
    await page.locator('vaadin-grid').getByRole('button').first().click();
    await takeScreenshot(page, arg, __filename, 'localization-changed');

    log(`Downloading and checking localization keys ...\n`);
    await page.getByLabel('Manage translations').locator('svg').click();
    const downloadPromise = page.waitForEvent('download');
    await page.getByText('Download translations').click();
    const download = await downloadPromise;
    const filePath = `${downloadsDir}/${download.suggestedFilename()}`;
    await download.saveAs(filePath);

    await run(`unzip -d ${downloadsDir} -o ${filePath}`);
    const str = await fs.readFileSync(`${downloadsDir}/${propsFile}`, 'utf8');
    assert(str.includes(`app.title=${appTitle}`));
    await fs.rmSync(downloadsDir, { recursive: true });
    await takeScreenshot(page, arg, __filename, 'title-translated');

    log(`Testing that preview page: ${previewUrl} shows ${appTitle} \n`);
    await pageApp.bringToFront();
    await pageApp.reload();
    await takeScreenshot(pageApp, arg, __filename, 'preview-ready');
    await expect(pageApp.getByRole('button', { name: 'New order' })).toBeVisible();
    await expect(pageApp.getByText(appTitle, { exact: true, timeout: 500 })).toBeVisible();

    log('Disabling Localizaton ...\n');
    await page.bringToFront();
    await page.getByRole('link', { name: 'Settings' }).click();
    await page.locator('vaadin-grid').getByText('bakery-cc', { exact: true }).click();
    await page.getByLabel('Localization').uncheck();
    await page.getByRole('button', { name: 'Disable' }).click();
    await page.getByRole('button', { name: 'Update' }).click();
    await takeScreenshot(pageApp, arg, __filename, 'localization-disabled');

    log(`Testing that preview page: ${previewUrl} shows ${keyTitle} \n`);
    await pageApp.bringToFront();
    await pageApp.reload();
    await takeScreenshot(pageApp, arg, __filename, 'preview-after-localization-disabled');
    await expect(pageApp.getByText(keyTitle, { exact: true })).toBeVisible();

    await closePage(pageApp, arg);
    await closePage(page, arg);
})();
