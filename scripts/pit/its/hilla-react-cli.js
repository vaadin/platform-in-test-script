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

  const page = await context.newPage();
  page.on('console', msg => console.log("> CONSOLE:", (msg.text() + ' - ' + msg.location().url).replace(/\s+/g, ' ')));
  page.on('pageerror', err => console.log("> PAGEERROR:", ('' + err).replace(/\s+/g, ' ')));

  await page.goto(`http://${host}:${port}/`);

  await page.locator('text=Hello').nth(0).click();
  await page.locator('input[type="text"]').fill('Greet');
  await page.locator('text=Say hello').click();
  await page.locator('text=Hello Greet');

  // ---------------------
  await context.close();
  await browser.close();
})();
