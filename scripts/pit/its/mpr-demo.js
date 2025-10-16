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
    headless: headless
  });
  const context = await browser.newContext({
    extraHTTPHeaders: {
      'X-AppUpdate': 'FOO'
    }
  });
  const page = await context.newPage();
  page.on('console', msg => console.log("> CONSOLE:", (msg.text() + ' - ' + msg.location().url).replace(/\s+/g, ' ')));
  page.on('pageerror', err => console.log("> PAGEERROR:", ('' + err).replace(/\s+/g, ' ')));

  await page.goto(`http://${host}:${port}`);
  await page.evaluate(() => {
    window.localStorage.setItem("vaadin.live-reload.dismissedNotifications","liveReloadUnavailable,preserveOnRefreshWarning")
    window.location.reload();
  });

  await page.locator('vaadin-notification-card[role="alert"]:has-text("Hello") div').nth(1).click();

  await page.getByRole('link', { name: 'Spreadsheet' }).click();
  await page.waitForURL(`http://${host}:${port}/spreadsheet`);

  await page.getByText('90', { exact: true }).click();
  await page.locator('div:nth-child(59)').dblclick();

  await page.locator('#cellinput').click();
  await page.locator('#cellinput').fill('=B4*3');
  await page.locator('#cellinput').press('Enter');  
  await page.getByText('270').click();

  await page.getByRole('link', { name: 'Tree' }).click();
  await page.waitForURL(`http://${host}:${port}/tree`);


  await page.locator('span.v-tree8-expander').nth(0).click()
  await page.locator('span.v-tree8-expander').nth(1).click()

  await page.getByRole('link', { name: 'Video' }).click();
  await page.waitForURL(`http://${host}:${port}/video`);
  await page.getByRole('link', { name: 'Legacy' }).click();

  await page.waitForURL(`http://${host}:${port}/legacy`);
  await page.getByText('Here we are!').click();

  await page.locator('vaadin-vertical-layout:has-text("SpreadsheetTreeVideoLegacy") path').click();
  await page.waitForURL(`http://${host}:${port}`);

  await context.close();
  await browser.close();
})();
