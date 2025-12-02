const { log, args, createPage, closePage, takeScreenshot, waitForServerReady, dismissDevmode } = require('./test-utils');

(async () => {
    const arg = args();

    const page = await createPage(arg.headless);

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

    log('Testing About page');
    await page.locator('text=About').nth(0).click();
    await page.locator('text=/This place/');
    await takeScreenshot(page, arg, __filename, 'about-page-tested');

    log('React starter tested successfully');
    await closePage(page, arg);
})();
