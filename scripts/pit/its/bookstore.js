const { chromium } = require('playwright');
let headless = false, host = 'localhost', port = '8080', mode = 'prod';
process.argv.forEach(a => {
  if (/^--headless/.test(a)) {
    headless = true;
  } else if (/^--port=/.test(a)) {
    port = a.split('=')[1];
  } else if (/^--mode=/.test(a)) {
    mode = a.split('=')[1];
  }
});


(async () => {
  const browser = await chromium.launch({
    headless: headless,
    chromiumSandbox: false
  });
  const sleep = ms => new Promise(r => setTimeout(r, ms));
  const context = await browser.newContext();
  const page = await context.newPage();
  page.on('console', msg => console.log("> CONSOLE:", (msg.text() + ' - ' + msg.location().url).replace(/\s+/g, ' ')));
  page.on('pageerror', err => console.log("> PAGEERROR:", ('' + err).replace(/\s+/g, ' ')));

  await page.goto(`http://${host}:${port}/`);
  if (mode == 'dev') {
    await page.getByText('Don’t show again').click();
    await page.getByText('Dismiss').nth(1).click();
  }
  await page.getByLabel('Username').click();
  await page.getByLabel('Username').fill('admin');
  await page.getByLabel('Username').press('Tab');
  await page.getByLabel('Password', { exact: true }).fill('admin');
  await page.getByRole('button', { name: 'Log in' }).click();


  // await page.getByRole('button', { name: 'New product' }).waitFor({state: "visible"});
  // await page.getByRole('button', { name: 'New product' }).click();
  // await page.waitForURL(`http://${host}:${port}/Inventory/new`);

  // await page.getByLabel('Product name', { exact: true }).waitFor({state: "visible"});
  // await page.getByLabel('Product name', { exact: true }).click();
  // await page.getByLabel('Product name', { exact: true }).fill('foo');
  // await page.getByLabel('Price', { exact: true }).click();
  // await page.getByLabel('Price', { exact: true }).fill('40.00');
  // await page.getByLabel('In stock').click();
  // await page.getByLabel('In stock').fill('50');

  // await page.getByLabel('Romance').check();
  // await page.getByRole('button', { name: 'Save' }).locator('div').click();
  // await page.locator('text=foo created').textContent();
  // await page.getByRole('link', { name: 'Admin' }).waitFor({state: "visible"});

  // await page.getByRole('link', { name: 'Admin' }).click();
  // await page.getByRole('button', { name: 'Add New Category' }).locator('span').nth(1).click();
  // await page.locator('vaadin-text-field').first().waitFor({state: "visible"});
  
  // await sleep(1000);
  // const c = (await page.locator('vaadin-text-field').all()).length - 1;
  // console.log(`> Found ${c} input elements`);
  // await page.locator('input').nth(c).click()
  // await page.locator('input').nth(c).fill('BBBB');
  // await page.locator('input').nth(c).press('Enter');

  await context.close();
  await browser.close();
})();
