const { log, args, createPage, closePage, takeScreenshot, waitForServerReady, dismissDevmode } = require('./test-utils');

(async () => {
    const arg = args();

    const page = await createPage(arg.headless);

    await waitForServerReady(page, arg.url);

    // Dismiss dev mode notification if present
    await dismissDevmode(page);
    await takeScreenshot(page, __filename, 'page-loaded');

    log('Testing React Todo view');
    await page.locator('text=Todo').nth(0).click();
    await takeScreenshot(page, __filename, 'todo-clicked');

    log('React view tested successfully');
    await closePage(page);
})();
