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
  const context = await browser.newContext({
    viewport: { width: 1024, height: 800 }
  });

  const page = await context.newPage();
  page.on('console', msg => console.log("> CONSOLE:", (msg.text() + ' - ' + msg.location().url).replace(/\s+/g, ' ')));
  page.on('pageerror', err => console.log("> PAGEERROR:", ('' + err).replace(/\s+/g, ' ')));

  await page.goto(`http://${host}:${port}/`);

  await page.waitForURL('http://localhost:8080/login');
  await page.locator('input[name="username"]').click();
  await page.locator('input[name="username"]').fill('admin');
  await page.locator('input[name="password"]').click();
  await page.locator('input[name="password"]').fill('admin');
  await page.locator('vaadin-button[role="button"]:has-text("Log in")').click();
  await page.waitForLoadState();

  await page.locator('text=Hello World').nth(0).click();
  await page.locator('text=Hello').nth(0).click();
  await page.locator('input[type="text"]').fill('Greet');
  await page.locator('text=Say hello').click();
  await page.locator('text=Hello Greet').waitFor({ state: 'visible' });

  // TODO: investigate why this is needed when notification is visible click does not work in master-detail
  await page.goto(`http://${host}:${port}/master-detail-view`);
  await page.locator('text=Master-Detail').nth(0).click();
  console.log('--- Click on eula.lane');
  await page.locator('text=eula.lane').click();
  await page.locator('input[type="text"]').nth(0).fill('FOO');

  // TODO: reduce screen height above and uncomment this when fixed
  // https://github.com/vaadin/start/issues/3521
  // await page.locator('text=Save').scrollIntoViewIfNeeded();
  await page.locator('text=Save').click();
  await page.locator('text=/Data updated/').waitFor({ state: 'visible' });
  await page.waitForTimeout(5000);

  await page.locator('text=/Emma/').click();
  await page.locator('text=/Sign out/').click();
  await page.locator('h2:has-text("Log in")');

  // ---------------------
  await context.close();
  await browser.close();
})();
