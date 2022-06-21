const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({
    headless: false
  });
  const context = await browser.newContext();

  // Open new page
  const page = await context.newPage();

  // Go to http://localhost:8080/
  await page.goto('http://localhost:8080/');

  // Click input[type="text"]
  await page.locator('input[type="text"]').click();

  // Fill input[type="text"]
  await page.locator('input[type="text"]').fill('Vaadiner');

  // Click text=Say hello
  await page.locator('text=Say hello').click();

  // Click text=Hello Vaadiner >> div >> nth=1
  await page.locator('text=Hello Vaadiner >> div').nth(1).click();

  // ---------------------
  await context.close();
  await browser.close();
})();
