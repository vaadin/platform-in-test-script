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
  page.on('console', msg => console.log("> CONSOLE:", msg.text()));
  page.on('pageerror', err => console.log("> JSERROR:", err));

  // Go to http://localhost:8080/
  await page.goto(`http://${host}:${port}/`);

  // Click input[type="text"]
  await page.locator('text=Click me').click({timeout:60000});

  // Click text=Say hello
  await page.locator('text=Clicked');

  // ---------------------
  await context.close();
  await browser.close();
})();
