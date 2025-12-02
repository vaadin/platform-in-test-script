const { log, args, createPage, closePage, takeScreenshot, waitForServerReady, dismissDevmode } = require('./test-utils');

(async () => {
    const arg = args();

    const page = await createPage(arg.headless);

    await waitForServerReady(page, arg.url, arg);

    // Dismiss dev mode notification if present
    await dismissDevmode(page);
    await takeScreenshot(page, arg, __filename, 'page-loaded');

    await page.locator('text=Hello').nth(0).click();
    await takeScreenshot(page, arg, __filename, 'hello-clicked');

    await page.locator('input[type="text"]').fill('Greet');
    await takeScreenshot(page, arg, __filename, 'input-filled');

    await page.locator('text=Say hello').click();
    await takeScreenshot(page, arg, __filename, 'say-hello-clicked');

    await page.locator('text=Hello Greet');
    await takeScreenshot(page, arg, __filename, 'greeting-displayed');

    await closePage(page, arg);
})();
