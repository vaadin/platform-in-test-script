const { log, args, createPage, closePage, takeScreenshot, waitForServerReady, dismissDevmode } = require('./test-utils');

(async () => {
    const arg = args();

    const page = await createPage(arg.headless);

    await waitForServerReady(page, arg.url, arg);

    // Dismiss dev mode notification if present
    await dismissDevmode(page);
    await takeScreenshot(page, arg, __filename, 'page-loaded');

    log('Testing Master-Detail (Javahtml) views');
    // Click text=Master-Detail (Javahtml) >> slot >> nth=1
    await page.locator('text=Master-Detail (Javahtml) >> slot').nth(1).click();
    await page.waitForURL(`${arg.url}/master-detail-view`);
    // Click text=Master-Detail SampleAddress (Javahtml) >> slot >> nth=1
    await page.locator('text=Master-Detail SampleAddress (Javahtml) >> slot').nth(1).click();
    await page.waitForURL(`${arg.url}/master-detail-view-sampleaddress`);
    // Click text=Master-Detail SampleBook (Javahtml) >> slot >> nth=1
    await page.locator('text=Master-Detail SampleBook (Javahtml) >> slot').nth(1).click();
    await page.waitForURL(`${arg.url}/master-detail-view-samplebook`);
    await takeScreenshot(page, arg, __filename, 'master-detail-javahtml-tested');

    log('Testing Hello World (Javahtml) view');
    // Click text=Hello World (Javahtml) >> slot >> nth=1
    await page.locator('text=Hello World (Javahtml) >> slot').nth(1).click();
    await page.waitForURL(`${arg.url}/hello-world-view`);
    // Fill input[type="text"]
    await page.locator('input[type="text"]').fill('Greet');
    // Click text=Say hello
    await page.locator('text=Say hello').click();
    await page.locator('text=Hello Greet');
    await takeScreenshot(page, arg, __filename, 'hello-world-javahtml-tested');

    log('All Javahtml views tested successfully');
    await closePage(page, arg);
})();
