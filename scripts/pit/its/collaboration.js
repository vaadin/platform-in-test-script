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

  await page.getByText('#support').click();
  await page.getByText('#casual').click();
  await page.getByText('#general').click();
  await page.getByLabel('Message').click();
  await page.getByLabel('Message').fill('Test');
  await page.getByRole('button', { name: 'Send' }).click();
  await page.getByRole('link', { name: 'Master Detail' }).click();
  await page.getByText('Gene', { exact: true }).click();
  await page.getByLabel('First Name', { exact: true }).click();
  await page.getByLabel('First Name', { exact: true }).fill('Gene James');
  await page.getByText('Marguerite', { exact: true }).click();
  await page.getByLabel('First Name', { exact: true }).click();
  await page.getByText('Cora', { exact: true }).click();
  await page.getByLabel('First Name', { exact: true }).click();
  await page.getByLabel('First Name', { exact: true }).fill('Cora Jane');
  await page.getByRole('button', { name: 'Save' }).click();
  await page.getByRole('button', { name: 'Cancel' }).click();

  // ---------------------
  await context.close();
  await browser.close();
})();
