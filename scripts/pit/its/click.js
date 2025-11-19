const { expect } = require('@playwright/test');
const { log, args, createPage, closePage, takeScreenshot, waitForServerReady, dismissDevmode } = require('./test-utils');

(async () => {
    const arg = args();

    const page = await createPage(arg.headless);

    await waitForServerReady(page, arg.url);

    // Dismiss dev mode notification if present
    await dismissDevmode(page);
    await takeScreenshot(page, __filename, 'page-loaded');

    // Click the "Click me" button
    await page.locator('text=Click me').click({timeout:60000});
    await takeScreenshot(page, __filename, 'button-clicked');

    // Wait for "Clicked" text to appear
    await page.locator('text=Clicked');
    await takeScreenshot(page, __filename, 'clicked-result');

    await closePage(page);
})();
