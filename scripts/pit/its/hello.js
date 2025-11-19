const { log, args, createPage, closePage, takeScreenshot, waitForServerReady, dismissDevmode } = require('./test-utils');

(async () => {
    const arg = args();

    const page = await createPage(arg.headless);

    await waitForServerReady(page, arg.url);

    // Dismiss dev mode notification if present
    await dismissDevmode(page);

    const text = 'Greet';

    // Wait for vaadin ready
    await page.waitForSelector('#outlet > * > *:not(style):not(script)');

    await takeScreenshot(page, __filename, 'initial-view');

    // Click input[type="text"]
    try {
        await page.locator('input[type="text"]').click({timeout:10000});
    } catch (error) {
        // skeleton-starter-flow-cdi wildfly:run sometimes does not load the page correctly
        log(`Error looking for input[type="text"], sleeping and reloading page`);
        await page.reload();
        await page.waitForLoadState('load')
        await page.waitForTimeout(10000);
        await takeScreenshot(page, __filename, 'initial-view-after-reload');
        await page.locator('input[type="text"]').click({timeout:60000});
    }

    // Fill input[type="text"]
    await page.locator('input[type="text"]').fill(text);
    await takeScreenshot(page, __filename, 'input-filled');

    // Click text=Say hello
    await page.locator('vaadin-button').click();
    await takeScreenshot(page, __filename, 'button-clicked');

    // Look for the text, sometimes rendered in an alert, sometimes in the dom
    let m;
    try {
        m = await page.getByRole('alert').nth(1).innerText({timeout:500});
        log(`Found ${text} in an 'alert' role: ${m}`);
    } catch (e) {
        log(`Not Found ${text} in an 'alert' role, looking in DOM`);
        m = await page.locator(`text=/${text}/`).innerText({timeout:5000});
    }

    if (! new RegExp(text).test(m)) {
        throw new Error(`${text} text not found in ${m}`);
    }

    log(`Found ${m} text in the dom`);
    await takeScreenshot(page, __filename, 'greeting-found');

    await closePage(page);
})();
