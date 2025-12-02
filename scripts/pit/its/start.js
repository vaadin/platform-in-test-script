const { log, args, createPage, closePage, takeScreenshot, waitForServerReady, dismissDevmode } = require('./test-utils');

(async () => {
    const arg = args();

    const page = await createPage(arg.headless);
    // TODO: should work with smaller viewport too like in 24.9
    page.setViewportSize({ width: 1920, height: 1080 });

    await waitForServerReady(page, arg.url, arg);

    // Dismiss dev mode notification if present
    await dismissDevmode(page);
    await takeScreenshot(page, arg, __filename, 'page-loaded');

    log('Testing Hello functionality');
    await page.locator('text=Hello').nth(0).click();
    await page.locator('input[type="text"]').fill('Greet');
    await page.locator('text=Say hello').click();
    await page.locator('text=Hello Greet');
    await takeScreenshot(page, arg, __filename, 'hello-tested');

    log('Testing Master-Detail functionality');
    await page.locator('text=Master-Detail').nth(0).click();
    await page.locator('text=eula.lane').click();
    await page.locator('input[type="text"]').nth(0).fill('FOO');
    await page.locator('text=Save').click();
    await page.locator('text=/stored/');
    await takeScreenshot(page, arg, __filename, 'master-detail-tested');

    log('Start application tested successfully');
    await closePage(page, arg);
})();
