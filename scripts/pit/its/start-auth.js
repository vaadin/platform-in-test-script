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
  page.on('console', msg => console.log("> CONSOLE:", msg.text()));
  page.on('pageerror', err => console.log("> JSERROR:", err));

  await page.goto(`http://${host}:${port}/`);

  await page.waitForURL('http://localhost:8080/login');
  await page.locator('input[name="username"]').click();
  await page.locator('input[name="username"]').fill('admin');
  await page.locator('input[name="password"]').click();
  await page.locator('input[name="password"]').fill('admin');
  await page.locator('vaadin-button[role="button"]:has-text("Log in")').click();
  await page.waitForLoadState();

  await page.locator('text=Hello World (Java)').nth(0).click();
  await page.locator('text=Hello').nth(0).click();
  await page.locator('input[type="text"]').fill('Greet');
  await page.locator('text=Say hello').click();
  await page.locator('text=Hello Greet');

  await page.locator('text=Master-Detail').nth(0).click();
  await page.locator('text=eula.lane').click();
  await page.locator('input[type="text"]').nth(0).fill('FOO');
  await page.locator('text=Save').click();
  await page.locator('text=/stored/');
  await page.waitForTimeout(5000);

  await page.locator('text=/Emma Powerful/').click();
  await page.locator('text=/Sign out/').click();
  await page.locator('h2:has-text("Log in")');

  // ---------------------
  await context.close();
  await browser.close();
})();
