const { log, args, createPage, closePage, takeScreenshot, waitForServerReady, dismissDevmode } = require('./test-utils');

(async () => {
    const arg = args();

    const page = await createPage(arg.headless);

    await waitForServerReady(page, arg.url);

    // Dismiss dev mode notification if present
    await dismissDevmode(page);
    await takeScreenshot(page, __filename, 'page-loaded');

    log('Testing Flow view functionality');
    await page.locator('text=Hello Flow').nth(0).click();
    await takeScreenshot(page, __filename, 'flow-view-opened');
    
    await page.locator('text=eula.lane').click();
    await takeScreenshot(page, __filename, 'flow-person-selected');
    
    await page.locator('input[type="text"]').nth(0).fill('FOO');
    await takeScreenshot(page, __filename, 'flow-input-filled');
    
    await page.locator('text=Save').click();
    await takeScreenshot(page, __filename, 'flow-save-clicked');
    
    await page.locator('text=/Updated/');
    await takeScreenshot(page, __filename, 'flow-update-confirmed');

    log('Testing Hilla view functionality');
    await page.locator('text=Hello Hilla').nth(0).click();
    await takeScreenshot(page, __filename, 'hilla-view-opened');
    
    await page.locator('text=eula.lane').click();
    await takeScreenshot(page, __filename, 'hilla-person-selected');
    
    await page.locator('input[type="text"]').nth(0).fill('FOO');
    await takeScreenshot(page, __filename, 'hilla-input-filled');
    
    await page.locator('text=Save').click();
    await takeScreenshot(page, __filename, 'hilla-save-clicked');
    
    await page.locator('text=/Stored/');
    await takeScreenshot(page, __filename, 'hilla-stored-confirmed');

    log('Hybrid application test completed successfully');

    await closePage(page);
})();
