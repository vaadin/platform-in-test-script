const { chromium } = require('playwright');

let headless = false, host = 'localhost', port = '8080', hub = false;
process.argv.forEach(a => {
  if (/^--headless/.test(a)) {
    headless = true;
  } else if (/^--ip=/.test(a)) {
    ip = a.split('=')[1];
  } else if (/^--port=/.test(a)) {
    port = a.split('=')[1];
  }
});

(async () => {
  const browser = await chromium.launch({
    headless: headless,
    chromiumSandbox: false
  });
  const context = await browser.newContext();

  // Open new page
  const page = await context.newPage();
  page.on('console', msg => console.log("> CONSOLE:", msg.text()))

  // Go to http://${host}:${port}/
  await page.goto(`http://${host}:${port}/`);

  // Click text=Empty (Java) >> slot >> nth=1
  await page.locator('text=Empty (Java) >> slot').nth(1).click();
  await page.waitForURL(`http://${host}:${port}/empty-view`);
  // Click text=Hello World (Java) >> slot >> nth=1
  await page.locator('text=Hello World (Java) >> slot').nth(1).click();
  await page.waitForURL(`http://${host}:${port}/hello-world-view`);

  // Fill input[type="text"]
  await page.locator('input[type="text"]').fill('Greet');
  // Click text=Say hello
  await page.locator('text=Say hello').click();
  await page.locator('text=Hello Greet');

  // Click text=Dashboard (Java) >> slot >> nth=1
  await page.locator('text=Dashboard (Java) >> slot').nth(1).click();
  await page.waitForURL(`http://${host}:${port}/dashboard-view`);
  // Click text=Card List (Java) >> slot >> nth=1
  await page.locator('text=Card List (Java) >> slot').nth(1).click();
  await page.waitForURL(`http://${host}:${port}/card-list-view`);
  // Click vcf-nav-item:nth-child(5) > a > slot:nth-child(2)
  await page.locator('vcf-nav-item:nth-child(5) > a > slot:nth-child(2)').click();
  await page.waitForURL(`http://${host}:${port}/list-view`);
  // Click vcf-nav-item:nth-child(6) > a > slot:nth-child(2)
  await page.locator('vcf-nav-item:nth-child(6) > a > slot:nth-child(2)').click();
  await page.waitForURL(`http://${host}:${port}/master-detail-view`);
  // Click vcf-nav-item:nth-child(7) > a > slot:nth-child(2)
  await page.locator('vcf-nav-item:nth-child(7) > a > slot:nth-child(2)').click();
  await page.waitForURL(`http://${host}:${port}/master-detail-view-sampleaddress`);
  // Click vcf-nav-item:nth-child(8) > a > slot:nth-child(2)
  await page.locator('vcf-nav-item:nth-child(8) > a > slot:nth-child(2)').click();
  await page.waitForURL(`http://${host}:${port}/master-detail-view-samplebook`);
  // Click text=Collaborative Master-Detail (Java) >> slot >> nth=1
  await page.locator('text=Collaborative Master-Detail (Java) >> slot').nth(1).click();
  await page.waitForURL(`http://${host}:${port}/collaborative-master-detail-view`);
  // Click text=Collaborative Master-Detail SampleAddress (Java) >> slot >> nth=1
  await page.locator('text=Collaborative Master-Detail SampleAddress (Java) >> slot').nth(1).click();
  await page.waitForURL(`http://${host}:${port}/collaborative-master-detail-view-sampleaddress`);
  // Click text=Collaborative Master-Detail SampleBook (Java) >> slot >> nth=1
  await page.locator('text=Collaborative Master-Detail SampleBook (Java) >> slot').nth(1).click();
  await page.waitForURL(`http://${host}:${port}/collaborative-master-detail-view-samplebook`);
  // Click text=Person Form (Java) >> slot >> nth=1
  await page.locator('text=Person Form (Java) >> slot').nth(1).click();
  await page.waitForURL(`http://${host}:${port}/person-form-view`);
  // Click text=Address Form (Java) >> slot >> nth=1
  await page.locator('text=Address Form (Java) >> slot').nth(1).click();
  await page.waitForURL(`http://${host}:${port}/address-form-view`);
  // Click text=Credit Card Form (Java) >> slot >> nth=1
  await page.locator('text=Credit Card Form (Java) >> slot').nth(1).click();
  await page.waitForURL(`http://${host}:${port}/credit-card-form-view`);
  // Click text=Map (Java) >> slot >> nth=1
  await page.locator('text=Map (Java) >> slot').nth(1).click();
  await page.waitForURL(`http://${host}:${port}/map-view`);
  // Click text=Chat (Java) >> slot >> nth=1
  await page.locator('text=Chat (Java) >> slot').nth(1).click();
  await page.waitForURL(`http://${host}:${port}/chat-view`);
  // Click text=Rich Text Editor (Java) >> slot >> nth=1
  await page.locator('text=Rich Text Editor (Java) >> slot').nth(1).click();
  await page.waitForURL(`http://${host}:${port}/editor-view`);
  // Click text=Image List (Java) >> slot >> nth=1
  await page.locator('text=Image List (Java) >> slot').nth(1).click();
  await page.waitForURL(`http://${host}:${port}/image-list-view`);
  // Click text=Checkout Form (Java) >> slot >> nth=1
  await page.locator('text=Checkout Form (Java) >> slot').nth(1).click();
  await page.waitForURL(`http://${host}:${port}/checkout-form-view`);

  // ---------------------
  await context.close();
  await browser.close();
})();
