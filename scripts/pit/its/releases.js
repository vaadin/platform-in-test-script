const { expect} = require('@playwright/test');
const {log, args, createPage, closePage, takeScreenshot, waitForServerReady, dismissDevmode} = require('./test-utils');

(async () => {
    const arg = args();

    const page = await createPage(arg.headless, arg.ignoreHTTPSErrors);

    // Wait until the app has actually rendered, not just until the server
    // answers. In dev mode the first response can arrive while the frontend is
    // still being built, and the assertions below then run against a blank page.
    await waitForServerReady(page, arg.url, arg,
        {selector: '#outlet > * > *:not(style):not(script)'});

    await page.locator('html').first().innerHTML();
    await takeScreenshot(page, arg, __filename, 'page-loaded');

    if (await dismissDevmode(page)) {
        await takeScreenshot(page, arg, __filename, `dev-mode-indicator-closed`);
    }

    await expect(page.getByText('Pre-releases per version').first()).toBeVisible();

    await page.getByText('by release count').click();

    await takeScreenshot(page, arg, __filename, 'releases-view');
    await expect(page.getByText('Releases per version').first()).toBeVisible();

    // Strip the qualifier before splitting: a branch snapshot like
    // "25.3-SNAPSHOT" has no patch segment, so minor would come out as
    // "3-SNAPSHOT" and the label would never match.
    const [major, minor] = arg.version.replace(/-.*$/, '').split('.');
    const labelRegex = new RegExp(`${major}\\.${minor}, `);
    await page.getByLabel(labelRegex).click();

    await takeScreenshot(page, arg, __filename, 'version-label-clicked');

    // The graph is built from the platform releases published on GitHub, so a
    // branch snapshot is never one of its points and has no release notes.
    // The series assertions above already cover the view for those.
    if (/SNAPSHOT/.test(arg.version)) {
        log(`Skipping the per version assertions, ${arg.version} is not a published release`);
        log(JSON.stringify(arg));
        await closePage(page, arg);
        return;
    }

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
