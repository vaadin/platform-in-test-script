const { log, args, createPage, closePage, takeScreenshot, waitForServerReady, dismissDevmode } = require('./test-utils');

(async () => {
    const arg = args();

    const page = await createPage(arg.headless);

    await waitForServerReady(page, arg.url, arg);

    // Dismiss dev mode notification if present
    await dismissDevmode(page);
    await takeScreenshot(page, arg, __filename, 'page-loaded');

    log('Testing Empty (Java) view navigation');
    await page.locator('text=Empty (Java) >> slot').nth(1).click();
    await page.goto(`${arg.url}/empty-view`);
    await takeScreenshot(page, arg, __filename, 'empty-view-loaded');

    log('Basic test completed successfully');
    await closePage(page, arg);
})();
