const { log, args, createPage, closePage, takeScreenshot, waitForServerReady, dismissDevmode } = require('./test-utils');

(async () => {
    const arg = args();
    const text = 'Greet';

    const page = await createPage(arg.headless);

    await waitForServerReady(page, arg.url, arg, {selector: '#outlet > * > *:not(style):not(script)'});

    // Dismiss dev mode notification if present
    await dismissDevmode(page);
    await takeScreenshot(page, arg, __filename, 'initial-view');

    // Click input[type="text"]
    try {
        await page.locator('input[type="text"]').click({timeout: 10000});
    } catch (error) {
        // skeleton-starter-flow-cdi wildfly:run sometimes does not load the page correctly
        log('Error looking for input[type="text"], sleeping and reloading page');
        await page.reload();
        await page.waitForLoadState('load');
        await page.waitForTimeout(10000);
        await takeScreenshot(page, arg, __filename, 'reload');
        await page.locator('input[type="text"]').click({timeout: 60000});
    }

    // Fill input[type="text"]
    await page.locator('input[type="text"]').fill(text);

    // Click the button
    await page.locator('vaadin-button').click();
    await takeScreenshot(page, arg, __filename, 'button-clicked');

    // Look for the text, sometimes rendered in an alert, sometimes in the dom
    let m;
    try {
        m = await page.getByRole('alert').nth(1).innerText({timeout: 500});
    } catch (e) {
        log(`Not Found ${text} in an 'alert' role`);
        m = await page.locator(`text=/${text}/`).first().innerText({timeout: 5000});
    }
    if (!new RegExp(text).test(m)) {
        throw new Error(`${text} text not found in ${m}`);
    }
    log(`Found ${m} text in the dom`);

    await closePage(page, arg);
})();
