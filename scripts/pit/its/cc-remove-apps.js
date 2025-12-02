const {log, args, createPage, closePage, takeScreenshot, waitForServerReady} = require('./test-utils');

const arg = args();

async function remove(app, page) {
    log(`Removing ${app}...\n`);
    await page.getByRole('link', { name: 'Settings', }).click();
    await takeScreenshot(page, arg, __filename, 'settings');

    const anchorSelector = `//vaadin-grid-cell-content[.//span[normalize-space(text())="${app}"]]`;
    const anchors = page.locator(anchorSelector);
    const c = await anchors.count();
    if (c <= 0) {
        log(`App ${app} not found`);
        return;
    }
    if (c == 1) {
        const text = await anchors.nth(0).textContent();
        log(`Found one element ${text}`);
    }
    if (c > 1) {
        log(`App ${app} link found multiple times`);
        for (let i = 0; i < c; i++) {
            const text = await anchors.nth(i).textContent();
            log(`Element ${i}: ${text}`);
        }
    }
    await anchors.nth(0).click();

    await page.getByRole('button', { name: 'Delete' }).click();
    await page.getByLabel('I understand that this will').check();
    await page.getByRole('button', { name: 'Delete' }).click();
}

(async () => {
    if (!arg.login) {
        log(`Skipping the setup of Control center because of missing --email= parameter\n`)
        process.exit(1);
    }
    const page = await createPage(arg.headless, arg.ignoreHTTPSErrors);
    await waitForServerReady(page, arg.url, arg);
    await takeScreenshot(page, arg, __filename, 'view-loaded');

    log(`Logging in as ${arg.login} ${arg.pass}...\n`);
    await page.getByLabel('Email').fill(arg.login);
    await page.getByLabel('Password').fill(arg.pass);
    await page.getByRole('button', {name: 'Sign In'}).click()
    await takeScreenshot(page, arg, __filename, 'logged-in');

    for (const app of ['bakery-cc', 'bakery', 'cc-starter']) {
        await remove(app, page);
    }

    await closePage(page, arg);
})();
