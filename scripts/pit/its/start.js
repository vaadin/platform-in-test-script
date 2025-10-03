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
  
  // TODO: should work with smaller viewport too like in 24.9
  const context = await browser.newContext({
    viewport: { width: 1920, height: 1080 }
  });

  const page = await context.newPage();
  page.on('console', msg => console.log("> CONSOLE:", (msg.text() + ' - ' + msg.location().url).replace(/\s+/g, ' ')));
  page.on('pageerror', err => console.log("> PAGEERROR:", ('' + err).replace(/\s+/g, ' ')));

  await page.goto(`http://${host}:${port}/`);

  await page.locator('text=Hello').nth(0).click();
  await page.locator('input[type="text"]').fill('Greet');
  await page.locator('text=Say hello').click();
  await page.locator('text=Hello Greet');

  await page.locator('text=Master-Detail').nth(0).click();
  await page.locator('text=eula.lane').click();
  await page.locator('input[type="text"]').nth(0).fill('FOO');
  await page.locator('text=Save').click();
  await page.locator('text=/stored/');

  // ---------------------
  await context.close();
  await browser.close();
})();
