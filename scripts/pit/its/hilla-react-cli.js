const { log, args, createPage, closePage, takeScreenshot, waitForServerReady, dismissDevmode } = require('./test-utils');

(async () => {
    const arg = args();

    const page = await createPage(arg.headless);

    await waitForServerReady(page, arg.url);

    // Dismiss dev mode notification if present
    await dismissDevmode(page);
    await takeScreenshot(page, __filename, 'page-loaded');

    await page.locator('text=Hello').nth(0).click();
    await takeScreenshot(page, __filename, 'hello-clicked');
    
    await page.locator('input[type="text"]').fill('Greet');
    await takeScreenshot(page, __filename, 'input-filled');
    
    await page.locator('text=Say hello').click();
    await takeScreenshot(page, __filename, 'say-hello-clicked');
    
    await page.locator('text=Hello Greet');
    await takeScreenshot(page, __filename, 'greeting-displayed');

    await closePage(page);
})();
