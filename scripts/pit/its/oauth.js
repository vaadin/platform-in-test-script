const { log, args, createPage, closePage, takeScreenshot, waitForServerReady, dismissDevmode } = require('./test-utils');

(async () => {
    const arg = args();

    const page = await createPage(arg.headless);

    await waitForServerReady(page, arg.url);

    // Dismiss dev mode notification if present
    await dismissDevmode(page);
    await takeScreenshot(page, __filename, 'page-loaded');

    log('Testing OAuth login flow');
    await page.waitForURL(`${arg.url.replace(':8080', ':8080')}/login`);
    await takeScreenshot(page, __filename, 'login-page');

    await page.getByRole('link', { name: 'Login with Google' }).click();
    await takeScreenshot(page, __filename, 'google-login-clicked');

    await page.locator('input[type=email]').fill('aaa');
    await page.getByRole('button').nth(2).click();
    await takeScreenshot(page, __filename, 'oauth-form-filled');

    log('OAuth flow tested successfully');
    await closePage(page);
})();
