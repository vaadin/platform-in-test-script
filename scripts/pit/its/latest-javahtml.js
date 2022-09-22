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

  // Go to http://localhost:8080/
  await page.goto(`http://${host}:${port}/`);


  // Click text=Master-Detail (Javahtml) >> slot >> nth=1
  await page.locator('text=Master-Detail (Javahtml) >> slot').nth(1).click();
  await page.waitForURL('http://localhost:8080/master-detail-view');
  // Click text=Master-Detail SampleAddress (Javahtml) >> slot >> nth=1
  await page.locator('text=Master-Detail SampleAddress (Javahtml) >> slot').nth(1).click();
  await page.waitForURL('http://localhost:8080/master-detail-view-sampleaddress');
  // Click text=Master-Detail SampleBook (Javahtml) >> slot >> nth=1
  await page.locator('text=Master-Detail SampleBook (Javahtml) >> slot').nth(1).click();
  await page.waitForURL('http://localhost:8080/master-detail-view-samplebook');
  // Click text=Hello World (Javahtml) >> slot >> nth=1
  await page.locator('text=Hello World (Javahtml) >> slot').nth(1).click();
  await page.waitForURL('http://localhost:8080/hello-world-view');
  // Fill input[type="text"]
  await page.locator('input[type="text"]').fill('Greet');
  // Click text=Say hello
  await page.locator('text=Say hello').click();
  await page.locator('text=Hello Greet');
  

  // ---------------------
  await context.close();
  await browser.close();
})();
