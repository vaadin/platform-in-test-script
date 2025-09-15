const { expect} = require('@playwright/test');
const {log, args, createPage, closePage, takeScreenshot, waitForServerReady, dismissDevmode} = require('./test-utils');

(async () => {
    const arg = args();

    const page = await createPage(arg.headless, arg.ignoreHTTPSErrors);

    await waitForServerReady(page, arg.url);

    await page.locator('html').first().innerHTML();
    await takeScreenshot(page, __filename, 'view1-loaded');

    if (await dismissDevmode(page)) {
        await takeScreenshot(page, __filename, `dev-mode-indicator-closed`);
    }

    await expect(page.getByText('Pre-releases per version').first()).toBeVisible();

    await page.getByText('by release count').click();

    await takeScreenshot(page, __filename, 'view3-loaded');
    await expect(page.getByText('Releases per version').first()).toBeVisible();

    const [major, minor] = arg.version.split('.');
    const labelRegex = new RegExp(`${major}\\.${minor}, `);
    await page.getByLabel(labelRegex).click();

    await takeScreenshot(page, __filename, `element-${labelRegex}-clicked`);
    let selector = `path.highcharts-point[aria-label*="${arg.version},"]`
    await expect(page.getByLabel('Interactive chart').locator(selector)).toBeVisible();
    await takeScreenshot(page, __filename, `interactive-chart-${arg.version}-loaded`);

    try {
        // click on the bullet image
        await page.locator('#chart').nth(1).getByRole('img', {name: arg.version + ', 1.'}).click({timeout: 1000});
    } catch (error) {
        // click on the tooltip
        await page.locator('#chart').nth(1).getByText(arg.version).first().click({timeout: 1000});
    }

    await expect(page.getByRole('heading', { name: `Release Notes for ${arg.version}` })).toBeVisible();
    await takeScreenshot(page, __filename, `release-notes-${arg.version}-loaded`);

    log(JSON.stringify(arg));
    await closePage(page);
})();