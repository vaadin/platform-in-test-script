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
    // TODO: happen in 25.0.0-beta9 (eg. default starter)
    // 1) <vaadin-button tabindex="0" role="button" theme="primary">Say hello</vaadin-button> aka getByRole('button', { name: 'Say hello' })
    // 2) <vaadin-button tabindex="0" role="button" has-tooltip="" part="toggle-button" aria-expanded="true" theme="icon tertiary" aria-label="Hide Log" aria-controls="content" aria-describedby="vaadin-tooltip-10">…</vaadin-button> aka getByLabel('Hide Log')
    // 3) <vaadin-button tabindex="0" role="button" theme="tertiary" part="title-button" class="cursor-inherit font-bold justify-start max-w-full overflow-hidden px-0 text-xs uppercase">…</vaadin-button> aka getByText('Log', { exact: true })
    // 4) <vaadin-button tabindex="0" role="button" has-tooltip="" part="popup-button" theme="icon tertiary" aria-label="Open Log as a popup" aria-describedby="vaadin-tooltip-11">…</vaadin-button> aka getByLabel('Open Log as a popup')
    await page.getByRole('button', { name: /hello/i }).click();

    // Look for the text, sometimes rendered in an alert, sometimes in the dom
    let m;
    try {
        m = await page.getByRole('alert').nth(1).innerText({timeout: 500});
    } catch (e) {
        log(`Not Found ${text} in an 'alert' role`);
        try {
            m = await page.locator(`text=/${text}/`).first().innerText({timeout: 500});
        } catch (error) {
            log(`Not Found ${text} in an 'text=/${text}/' locator`);
        }
    }
    await takeScreenshot(page, arg, __filename, 'button-clicked');
    if (!new RegExp(text).test(m)) {
        throw new Error(`${text} text not found in ${m}`);
    }
    log(`Found ${m} text in the dom`);

    await closePage(page, arg);
})();
