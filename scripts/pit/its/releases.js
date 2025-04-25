const { expect} = require('@playwright/test');
const {log, args, createPage, closePage, takeScreenshot, waitForServerReady} = require('./test-utils');

(async () => {
    const arg = args();

    const page = await createPage(arg.headless, arg.ignoreHTTPSErrors);

    await waitForServerReady(page, arg.url);

    await page.locator('html').first().innerHTML();
    await takeScreenshot(page, __filename, 'view1-loaded');
    await expect(page.getByText('Pre-releases per version').first()).toBeVisible();

    await page.getByText('by release count').click();

    await takeScreenshot(page, __filename, 'view3-loaded');
    await expect(page.getByText('Releases per version').first()).toBeVisible();

    if (arg.version && arg.version !== 'current') {
        const [major, minor] = arg.version.split('.');
        const labelRegex = new RegExp(`${major}\\.${minor}, `);
        await page.getByLabel(labelRegex).click();
        await expect(page.getByLabel('Interactive chart').locator('text').getByText(arg.version)).toBeVisible();

        await page.getByText(arg.version).first().click();
        await expect(page.getByRole('heading', { name: `Release Notes for ${arg.version}` })).toBeVisible();
    }

    log(JSON.stringify(arg));
    await closePage(page);
})();