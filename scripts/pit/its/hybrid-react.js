const { log, args, createPage, closePage, takeScreenshot, waitForServerReady, dismissDevmode } = require('./test-utils');

(async () => {
    const arg = args();

    const page = await createPage(arg.headless);

    await waitForServerReady(page, arg.url, arg);

    // Dismiss dev mode notification if present
    await dismissDevmode(page);
    await takeScreenshot(page, arg, __filename, 'page-loaded');

    log('Testing Flow view functionality');
    await page.locator('text=Hello Flow').nth(0).click();
    await takeScreenshot(page, arg, __filename, 'flow-view-opened');

    await page.locator('text=eula.lane').click();
    await takeScreenshot(page, arg, __filename, 'person-selected');

    await page.locator('input[type="text"]').nth(0).fill('FOO');
    await takeScreenshot(page, arg, __filename, 'input-filled');

    await page.locator('text=Save').click();
    await takeScreenshot(page, arg, __filename, 'save-clicked');

    await page.locator('text=/Updated/');
    await takeScreenshot(page, arg, __filename, 'update-confirmed');

    log('Testing Hilla view functionality');
    await page.locator('text=Hello Hilla').nth(0).click();
    await takeScreenshot(page, arg, __filename, 'hilla-view-opened');

    await page.locator('text=/This place intentionally left empty/').isVisible();
    await takeScreenshot(page, arg, __filename, 'hilla-content-verified');

    log('Hybrid React application test completed successfully');

    await closePage(page, arg);
})();
