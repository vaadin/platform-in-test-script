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
  const sleep = ms => new Promise(r => setTimeout(r, ms));

  const page = await context.newPage();
  page.on('console', msg => console.log("> CONSOLE:", msg.text()));
  page.on('pageerror', err => console.log("> JSERROR:", err));

  await page.goto(`http://${host}:${port}`);
  await page.evaluate(() => {
    window.localStorage.setItem("vaadin.live-reload.dismissedNotifications","liveReloadUnavailable,preserveOnRefreshWarning")
    window.location.reload();
  });

  await page.getByRole('link', { name: 'Basic functionality' }).click();
  await page.waitForURL(`http://${host}:${port}/demo/basic`);

  await page.locator('.col2').first().click();
  const c = await page.getByText('SIMPLE MONTHLY BUDGET').count();
  if (c != 2) throw new Error();

  await page.getByRole('link', { name: 'Collaborative features' }).click();
  await page.waitForURL(`http://${host}:${port}/demo/collaborative`);
  await page.locator('vaadin-spreadsheet div:has-text("Loan calculator")').nth(2).click();
  await page.getByText('5.00%').dblclick();
  await page.locator('#cellinput').click();
  await page.locator('#cellinput').fill('0.03');
  await page.locator('#cellinput').press('Enter');  
  await page.getByText('$10,315.49');
  await sleep(100);
  await page.keyboard.press('Enter');
  await sleep(100);
  await page.locator('#cellinput').click();
  await page.locator('#cellinput').fill('20');
  await page.locator('#cellinput').press('Enter');  
  await page.getByText('$13,310.34').click();
  await sleep(100);

  await page.getByRole('link', { name: 'Grouping' }).click();
  await page.waitForURL(`http://${host}:${port}/demo/grouping`);
  await page.getByText('+').nth(3).click();
  await page.getByText('December').click();

  await page.getByRole('link', { name: 'Report mode' }).click();
  await page.waitForURL(`http://${host}:${port}/demo/reportMode`);
  await page.getByText('547 Demo Suites #85').click();

  await page.getByRole('link', { name: 'Simple invoice' }).click();
  await page.waitForURL(`http://${host}:${port}/demo/simpleInvoice`);
  await page.getByText('547 Demo Suites #85').click();

  await context.close();
  await browser.close();
})();
