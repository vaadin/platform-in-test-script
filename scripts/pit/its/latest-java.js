const { log, args, createPage, closePage, takeScreenshot, waitForServerReady, dismissDevmode } = require('./test-utils');

(async () => {
    const arg = args();

    const page = await createPage(arg.headless);

    await waitForServerReady(page, arg.url, arg);

    // Dismiss dev mode notification if present
    await dismissDevmode(page);
    await takeScreenshot(page, arg, __filename, 'page-loaded');

    log('Testing Empty (Java) view');
    // Click text=Empty (Java) >> slot >> nth=1
    await page.locator('text=Empty (Java) >> slot').nth(1).click();
    await page.waitForURL(`${arg.url}/empty-view`);

    log('Testing Hello World (Java) view');
    // Click text=Hello World (Java) >> slot >> nth=1
    await page.locator('text=Hello World (Java) >> slot').nth(1).click();
    await page.waitForURL(`${arg.url}/hello-world-view`);

    // Fill input[type="text"]
    await page.locator('input[type="text"]').fill('Greet');
    // Click text=Say hello
    await page.locator('text=Say hello').click();
    await page.locator('text=Hello Greet');
    await takeScreenshot(page, arg, __filename, 'hello-world-tested');

    log('Testing Dashboard (Java) view');
    // Click text=Dashboard (Java) >> slot >> nth=1
    await page.locator('text=Dashboard (Java) >> slot').nth(1).click();
    await page.waitForURL(`${arg.url}/dashboard-view`);
    await takeScreenshot(page, arg, __filename, 'dashboard-loaded');

    log('Testing Card List (Java) view');
    // Click text=Card List (Java) >> slot >> nth=1
    await page.locator('text=Card List (Java) >> slot').nth(1).click();
    await page.waitForURL(`${arg.url}/card-list-view`);

    log('Testing List view');
    // Click vcf-nav-item:nth-child(5) > a > slot:nth-child(2)
    await page.locator('vcf-nav-item:nth-child(5) > a > slot:nth-child(2)').click();
    await page.waitForURL(`${arg.url}/list-view`);

    log('Testing Master-Detail views');
    // Click vcf-nav-item:nth-child(6) > a > slot:nth-child(2)
    await page.locator('vcf-nav-item:nth-child(6) > a > slot:nth-child(2)').click();
    await page.waitForURL(`${arg.url}/master-detail-view`);
    // Click vcf-nav-item:nth-child(7) > a > slot:nth-child(2)
    await page.locator('vcf-nav-item:nth-child(7) > a > slot:nth-child(2)').click();
    await page.waitForURL(`${arg.url}/master-detail-view-sampleaddress`);
    // Click vcf-nav-item:nth-child(8) > a > slot:nth-child(2)
    await page.locator('vcf-nav-item:nth-child(8) > a > slot:nth-child(2)').click();
    await page.waitForURL(`${arg.url}/master-detail-view-samplebook`);
    await takeScreenshot(page, arg, __filename, 'master-detail-views-tested');

    log('Testing Collaborative Master-Detail views');
    // Click text=Collaborative Master-Detail (Java) >> slot >> nth=1
    await page.locator('text=Collaborative Master-Detail (Java) >> slot').nth(1).click();
    await page.waitForURL(`${arg.url}/collaborative-master-detail-view`);
    // Click text=Collaborative Master-Detail SampleAddress (Java) >> slot >> nth=1
    await page.locator('text=Collaborative Master-Detail SampleAddress (Java) >> slot').nth(1).click();
    await page.waitForURL(`${arg.url}/collaborative-master-detail-view-sampleaddress`);
    // Click text=Collaborative Master-Detail SampleBook (Java) >> slot >> nth=1
    await page.locator('text=Collaborative Master-Detail SampleBook (Java) >> slot').nth(1).click();
    await page.waitForURL(`${arg.url}/collaborative-master-detail-view-samplebook`);

    log('Testing Form views');
    // Click text=Person Form (Java) >> slot >> nth=1
    await page.locator('text=Person Form (Java) >> slot').nth(1).click();
    await page.waitForURL(`${arg.url}/person-form-view`);
    // Click text=Address Form (Java) >> slot >> nth=1
    await page.locator('text=Address Form (Java) >> slot').nth(1).click();
    await page.waitForURL(`${arg.url}/address-form-view`);
    // Click text=Credit Card Form (Java) >> slot >> nth=1
    await page.locator('text=Credit Card Form (Java) >> slot').nth(1).click();
    await page.waitForURL(`${arg.url}/credit-card-form-view`);
    await takeScreenshot(page, arg, __filename, 'forms-tested');

    log('Testing additional Java views');
    // Click text=Map (Java) >> slot >> nth=1
    await page.locator('text=Map (Java) >> slot').nth(1).click();
    await page.waitForURL(`${arg.url}/map-view`);
    // Click text=Chat (Java) >> slot >> nth=1
    await page.locator('text=Chat (Java) >> slot').nth(1).click();
    await page.waitForURL(`${arg.url}/chat-view`);
    // Click text=Rich Text Editor (Java) >> slot >> nth=1
    await page.locator('text=Rich Text Editor (Java) >> slot').nth(1).click();
    await page.waitForURL(`${arg.url}/editor-view`);
    // Click text=Image List (Java) >> slot >> nth=1
    await page.locator('text=Image List (Java) >> slot').nth(1).click();
    await page.waitForURL(`${arg.url}/image-list-view`);
    // Click text=Checkout Form (Java) >> slot >> nth=1
    await page.locator('text=Checkout Form (Java) >> slot').nth(1).click();
    await page.waitForURL(`${arg.url}/checkout-form-view`);
    await takeScreenshot(page, arg, __filename, 'all-java-views-tested');

    log('All Java views tested successfully');
    await closePage(page, arg);
})();
