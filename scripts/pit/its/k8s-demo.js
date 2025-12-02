const { log, args, createPage, closePage, takeScreenshot, waitForServerReady, dismissDevmode, setupCopilotConfig} = require('./test-utils');

(async () => {
    const arg = args();

    setupCopilotConfig();

    const page = await createPage(arg.headless, arg.ignoreHTTPSErrors);
    await waitForServerReady(page, arg.url, arg);

    await page.evaluate(() =>
        window.localStorage.setItem("vaadin.live-reload.dismissedNotifications","liveReloadUnavailable,preserveOnRefreshWarning")
    );

    await takeScreenshot(page, arg, __filename, 'page-loaded');

    log('Testing login flow');
    await page.waitForURL(`${arg.url}login`);
    await page.getByLabel('Username').fill('admin');
    await page.getByLabel('Username').press('Tab');
    await page.getByLabel('Password').first().fill('admin');
    await page.getByLabel('Password').first().press('Tab');
    await page.getByRole('button', { name: 'Log in' }).locator('div').click();
    await takeScreenshot(page, arg, __filename, 'logged-in');
    await page.waitForURL(`${arg.url}`);

    log('Testing Personas navigation');
    await page.getByRole('link').locator('text=/Personas/').click();
    await takeScreenshot(page, arg, __filename, 'personas');
    await page.waitForURL(`${arg.url}personas`);

    await dismissDevmode(page);
    await takeScreenshot(page, arg, __filename, 'devmode-dismissed');

    log('Testing person creation form');
    await page.getByRole('button', { name: '+' }).locator('div').click();
    await takeScreenshot(page, arg, __filename, 'new-person-form');
    await page.waitForURL(`${arg.url}personas/new`);

    await page.locator('.detail').getByLabel('First Name').click();
    await page.locator('.detail').getByLabel('First Name').fill('FOOBAR');
    await page.locator('.detail').getByLabel('First Name').press('Tab');
    await page.locator('.detail').getByLabel('Last Name').fill('BAZ');
    await page.locator('.detail').getByLabel('Last Name').press('Tab');
    await page.locator('.detail').getByLabel('First Name').click();
    await page.locator('.detail').getByLabel('Email').press('Escape');
    await takeScreenshot(page, arg, __filename, 'form-filled');

    log('Testing form preservation after reload');
    await page.evaluate(() => window.location.reload());
    await takeScreenshot(page, arg, __filename, 'page-reloaded');
    await page.waitForURL(`${arg.url}personas/new`);

    await page.getByRole('button', { name: 'No' }).locator('div').click();
    await takeScreenshot(page, arg, __filename, 'no-clicked');
    const name = await page.locator('.detail').getByLabel('First Name').inputValue();
    if (name != 'FOOBAR') throw new Error();

    log('K8s demo tested successfully');
    await closePage(page, arg);
})();
