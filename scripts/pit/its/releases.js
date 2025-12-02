const { expect} = require('@playwright/test');
const {log, args, createPage, closePage, takeScreenshot, waitForServerReady, dismissDevmode} = require('./test-utils');

(async () => {
    const arg = args();

    const page = await createPage(arg.headless, arg.ignoreHTTPSErrors);

    await waitForServerReady(page, arg.url, arg);

    await page.locator('html').first().innerHTML();
    await takeScreenshot(page, arg, __filename, 'page-loaded');

    if (await dismissDevmode(page)) {
        await takeScreenshot(page, arg, __filename, `dev-mode-indicator-closed`);
    }

    await expect(page.getByText('Pre-releases per version').first()).toBeVisible();

    await page.getByText('by release count').click();

    await takeScreenshot(page, arg, __filename, 'releases-view');
    await expect(page.getByText('Releases per version').first()).toBeVisible();

    const [major, minor] = arg.version.split('.');
    const labelRegex = new RegExp(`${major}\\.${minor}, `);
    await page.getByLabel(labelRegex).click();

    await takeScreenshot(page, arg, __filename, 'version-label-clicked');
    let selector = `path.highcharts-point[aria-label*="${arg.version},"]`
    await expect(page.getByLabel('Interactive chart').locator(selector)).toBeVisible();
    await takeScreenshot(page, arg, __filename, 'chart-loaded');

    try {
        // click on the bullet image
        await page.locator('#chart').nth(1).getByRole('img', {name: arg.version + ', 1.'}).click({timeout: 1000});
    } catch (error) {
        // click on the tooltip
        await page.locator('#chart').nth(1).getByText(arg.version).first().click({timeout: 1000});
    }

    await expect(page.getByRole('heading', { name: `Release Notes for ${arg.version}` })).toBeVisible();
    await takeScreenshot(page, arg, __filename, 'release-notes-loaded');

    log(JSON.stringify(arg));
    await closePage(page, arg);
})();
