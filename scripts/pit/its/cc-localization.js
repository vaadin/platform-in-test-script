const { expect} = require('@playwright/test');
const fs = require('fs');
const {log, err, args, run, createPage, closePage, takeScreenshot, waitForServerReady} = require('./test-utils');
const { assert } = require('console');

(async () => {
    const arg = args();
    if (!arg.login) {
        log(`Skipping the setup of Control center because of missing --email= parameter\n`)
        process.exit(1);
    }
    const app = `bakery-cc`;
    const user = 'admin@vaadin.com';
    const password = 'admin';
    const downloadsDir = './downloads';
    const propsFile = 'translations.properties';

    const page = await createPage(arg.headless, arg.ignoreHTTPSErrors);
    await waitForServerReady(page, arg.url);

    await expect(page.getByLabel('Email')).toBeVisible();
    await takeScreenshot(page, __filename, 'view-loaded');

    log(`Logging in CC as ${arg.login} ${arg.pass}...\n`);
    await page.getByLabel('Email').fill(arg.login);
    await page.getByLabel('Password').fill(arg.pass);
    await page.getByRole('button', {name: 'Sign In'}).click()
    await takeScreenshot(page, __filename, 'logged-in');

    log(`Changing Settings for ${app}...\n`);
    await page.getByRole('link', { name: 'Settings', }).click();
    await takeScreenshot(page, __filename, 'settings');
    const anchorSelectorURL = `//vaadin-grid-cell-content[.//span[normalize-space(text())="${app}"]]//a`;
    const url = await page.locator(anchorSelectorURL).getAttribute('href');
    const previewUrl = url.replace(/:\/\//, '://preview.');

    log(`Checking that  ${app} installed in ${url} is running ...\n`);
    // When app is not running, localization cannot be enabled
    const pageApp = await createPage(arg.headless, true);
    await waitForServerReady(pageApp, url);
    await takeScreenshot(pageApp, __filename, 'app-running');
    await closePage(pageApp);

    log(`Uploading and updating localization keys ...\n`);
    await page.locator('vaadin-select vaadin-input-container div').click();
    await page.getByRole('option', { name: app }).locator('div').nth(2).click();
    await takeScreenshot(page, __filename, 'selected-app');

    await page.getByRole('link', { name: 'Localization' }).click();
    await page.getByRole('button', { name: 'Enable Localization' }).click();
    await takeScreenshot(page, __filename, 'localization-enabled');

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
    
    await takeScreenshot(page, __filename, 'localization-loaded');
    await page.getByText('Bakery', { exact: true }).click();
    await page.locator('vaadin-text-area.inline textarea').fill('Panaderia');
    await page.locator('vaadin-grid').getByRole('button').first().click();
    await takeScreenshot(page, __filename, 'localization-changed');

    log(`Downloading and checking localization keys ...\n`);
    await page.getByLabel('Manage translations').locator('svg').click();
    const downloadPromise = page.waitForEvent('download');
    await page.getByText('Download translations').click();
    const download = await downloadPromise;
    const filePath = `${downloadsDir}/${download.suggestedFilename()}`;
    await download.saveAs(filePath);

    await run(`unzip -d ${downloadsDir} -o ${filePath}`);
    const str = await fs.readFileSync('./downloads/translations.properties', 'utf8');
    assert(str.includes('app.title=Panaderia'));
    await fs.rmSync(downloadsDir, { recursive: true });

    log(`Testing that preview page: ${previewUrl} is up and running\n`);
    await page.getByRole('button', { name: 'Start preview' }).click();
    const pagePrev = await createPage(arg.headless, true);
    await waitForServerReady(pagePrev, previewUrl);
    await takeScreenshot(pagePrev, __filename, 'preview-ready');
    const text = await pagePrev.getByText(/Password|Dashboard/).textContent();
    if (text.includes('Password')) {
        await pagePrev.getByLabel('Email').fill(user);
        await pagePrev.getByLabel('Password').fill(password);
        await pagePrev.getByRole('button', {name: 'Sign In'}).click()
        await takeScreenshot(pagePrev, __filename, 'preview-logged-in');
        await expect(pagePrev.getByRole('button', { name: 'New order' })).toBeVisible();
        await takeScreenshot(pagePrev, __filename, 'preview-loaded');
    }
    // await expect(pagePrev.getByText('Panaderia', { exact: true })).toBeVisible();
    await closePage(pagePrev);

    log('Cleaning up...\n');
    try {
        await page.getByRole('button', { name: 'Stop preview' }).click();
        await page.getByRole('link', { name: 'Settings' }).click();
        await page.waitForTimeout(2000);
        await page.locator('vaadin-grid').getByText('bakery-cc', { exact: true }).click();
        await page.waitForTimeout(2000);
        await page.getByLabel('Localization').uncheck();
        await page.getByRole('button', { name: 'Disable' }).click();
        await page.getByRole('button', { name: 'Update' }).click();
    } catch (error) {
        err(`Error cleaning up: ${error}\n`);
        await takeScreenshot(page, __filename, 'error-cleaning');
    }
    await closePage(page);
})();
