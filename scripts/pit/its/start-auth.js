const { log, args, createPage, closePage, takeScreenshot, waitForServerReady, dismissDevmode } = require('./test-utils');

(async () => {
    const arg = args();

    const page = await createPage(arg.headless);

    await waitForServerReady(page, arg.url);
    await takeScreenshot(page, __filename, 'page-loaded');

    log('Testing authentication login flow');
    await page.locator('input[name="username"]').click();
    await page.locator('input[name="username"]').fill('admin');
    await page.locator('input[name="password"]').click();
    await page.locator('input[name="password"]').fill('admin');
    await page.locator('vaadin-button[role="button"]:has-text("Log in")').click();
    await page.waitForLoadState();
    await takeScreenshot(page, __filename, 'logged-in');

    log('Testing Hello World functionality after login');
    await page.locator('text=Hello World').nth(0).click();
    await page.locator('text=Hello').nth(0).click();
    await page.locator('input[type="text"]').fill('Greet');
    await page.locator('text=Say hello').click();
    await page.locator('text=Hello Greet').waitFor({ state: 'visible' });
    await takeScreenshot(page, __filename, 'hello-world-tested');

    log('Testing Master-Detail functionality');
    // TODO: investigate why this is needed when notification is visible click does not work in master-detail
    await page.goto(`${arg.url}master-detail-view`);
    await page.locator('text=Master-Detail').nth(0).click();
    log('--- Click on eula.lane');
    await page.locator('text=eula.lane').click();
    await page.locator('input[type="text"]').nth(0).fill('FOO');
    await takeScreenshot(page, __filename, 'master-detail-editing');

    // TODO: reduce screen height above and uncomment this when fixed
    // https://github.com/vaadin/start/issues/3521
    // await page.locator('text=Save').scrollIntoViewIfNeeded();
    await page.locator('text=Save').click();
    await page.locator('text=/Data updated/').waitFor({ state: 'visible' });
    await page.waitForTimeout(5000);
    await takeScreenshot(page, __filename, 'data-updated');

    log('Testing logout functionality');
    await page.locator('text=/Emma/').click();
    await page.locator('text=/Sign out/').click();
    await page.locator('h2:has-text("Log in")');
    await takeScreenshot(page, __filename, 'logged-out');

    log('Authentication flow tested successfully');
    await closePage(page);
})();
