const { expect } = require('@playwright/test');
const { log, args, createPage, closePage, takeScreenshot, waitForServerReady, dismissDevmode } = require('./test-utils');

(async () => {
    const arg = args();
    const page = await createPage(arg.headless, arg.ignoreHTTPSErrors);

    // The app loads its dataset into H2 at start-up, wait until Home has rendered
    await waitForServerReady(page, arg.url, arg, { selector: 'text=About this demo' });
    await dismissDevmode(page);
    await takeScreenshot(page, arg, __filename, 'home');

    // --- Home ---
    log('Testing Home');
    await expect(page.getByRole('heading', { name: 'About this demo' })).toBeVisible();
    await expect(page.getByText('Nordic Supply').first()).toBeVisible();

    // Each view opens its readme in a popover by the Help entry on its first visit, close it before going on
    const readme = page.locator('vaadin-popover.help[opened]');
    const openView = async (name, firstVisit = true) => {
        await page.locator('vaadin-side-nav-item').filter({ hasText: name }).first().click();
        await expect(page).toHaveTitle(new RegExp(`^${name} \\|`));
        if (firstVisit) {
            await readme.waitFor({ state: 'attached', timeout: 20000 });
            await page.keyboard.press('Escape');
            await expect(readme).toHaveCount(0);
        }
    };

    // --- Lists: read-only grids over the generated data ---
    const grid = page.locator('main vaadin-grid');
    const cells = (text) => grid.locator('vaadin-grid-cell-content').filter({ hasText: text });
    for (const [view, header, row] of [
        ['Orders', 'Promised delivery', /^SO-\d{4}-\d+$/],
        ['Customers', 'Terms (days)', /^C-\d+$/],
        ['Products', 'List price (EUR)', /^[A-Z]+-[A-Z]+-\d+$/]]) {
        log(`Testing ${view}`);
        await openView(view);
        await expect(cells(header)).toHaveCount(1);
        await expect(cells(row).first()).toBeVisible();
        await takeScreenshot(page, arg, __filename, view.toLowerCase());
    }

    // --- Orders search ---
    log('Testing Orders search');
    await openView('Orders', false);
    const orderNumber = /^SO-\d{4}-\d+$/;
    const firstOrder = (await cells(orderNumber).first().textContent()).trim();
    await page.locator('main input[placeholder^="Search order number"]').fill(firstOrder);
    // The grid reuses its cells for the rows it no longer shows, so count the items instead
    await expect.poll(() => grid.evaluate(g => g.size)).toBe(1);
    await expect(cells(orderNumber).first()).toHaveText(firstOrder);
    await takeScreenshot(page, arg, __filename, 'orders-search');

    // --- Dashboard: asking needs a live model, so only check the default widgets render ---
    log('Testing Dashboard');
    await openView('Dashboard');
    await expect(page.getByRole('button', { name: 'Save Dashboard' })).toBeVisible();
    await expect(page.locator('vaadin-dashboard')).toBeVisible();
    await expect(page.locator('vaadin-dashboard vaadin-grid').first()).toBeVisible();
    await takeScreenshot(page, arg, __filename, 'dashboard');

    // --- Claims ---
    log('Testing Claims');
    await openView('Claims');
    await expect(page.getByText('New Claim Based on Customer Request')).toBeVisible();
    await expect(page.getByText('Damaged pallet.pdf')).toBeVisible();
    await takeScreenshot(page, arg, __filename, 'claims');

    // --- Activity Log ---
    log('Testing Activity Log');
    await openView('Activity Log');
    await expect(cells('Tokens in / out')).toHaveCount(1);
    await takeScreenshot(page, arg, __filename, 'activity-log');

    log('All ai-integrations-demo tests passed');
    await closePage(page, arg);
})();
