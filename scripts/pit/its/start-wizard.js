const { chromium } = require('playwright');

let headless = false, host = 'localhost', port = '8080', mode = false;
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
  const log = s => process.stderr.write(`   ${s}`);

  const context = await browser.newContext();
  context.setDefaultTimeout(90000);
  context.setDefaultNavigationTimeout(90000)

  const page = await context.newPage();
  page.setViewportSize({width: 811, height: 1224});

  page.on('console', msg => console.log("> CONSOLE:", (msg.text() + ' - ' + msg.location().url).replace(/\s+/g, ' ')));
  page.on('pageerror', err => console.log("> PAGEERROR:", ('' + err).replace(/\s+/g, ' ')));

  await page.goto(`http://${host}:${port}/`);

  // Navigate views from the new views menu
  await page.getByRole('button', { name: 'Close Tour' }).click();
  await page.frameLocator('iframe[title="Preview"]').getByLabel('Your name').click();
  await page.frameLocator('iframe[title="Preview"]').getByLabel('Your name').fill('Manolo');
  await page.getByText('About', { exact: true }).click();

  // Add all possible views
  const views = ['Empty', 'Dashboard Pro', 'Card List', 'List Pro', 'Master-Detail', 'Collaborative Master-Detail', 'Person Form Editable', 'Address Form', 'Credit Card Form', 'Map Pro', 'Spreadsheet Pro', 'Rich Text Editor Pro', 'Image List', 'Checkout Form', 'Grid with Filters', 'Hello World for Designer', 'Master-Detail for Designer', 'Hello World using Hilla', 'Master-Detail using Hilla'];
  for (const label of views) {
    await page.getByRole('button', { name: 'Add view' }).locator('span').nth(1).click();
    await page.getByRole('option', { name: label }).first().getByText(label).click();
    await sleep(500);
  }

  // Change Colors
  await page.getByRole('tab', { name: 'Theme' }).click();
  await page.getByRole('button', { name: 'Color' }).click();
  await page.getByText('Dark').click();
  await page.locator('[id="colors\\.base"] span').click();
  await page.locator('#saturation').click();
  await page.locator('#hue').click();
  await page.locator('#saturation').click();
  await page.locator('#saturation').press('Escape');

  // Navigate Views from the generated app menu
  const routes = ['Hello World', 'About', 'Empty', 'Dashboard', 'Card List', 'List', 'Master-Detail', 'Collaborative Master-Detail', 'Person Form', 'Address Form', 'Credit Card Form', 'Map', 'Spreadsheet', 'Rich Text Editor', 'Image List', 'Checkout Form', 'Grid with Filters', 'Hello World2', 'Master-Detail2', 'Hello World3', 'Master-Detail3'];
  for (const label of routes) {
    log(`Visited view ${label}\n`);
    await page.frameLocator('iframe[title="Preview"]').getByRole('button', { name: 'Menu toggle' }).locator('#slot div').click();
    await page.frameLocator('iframe[title="Preview"]').getByRole('link', { name: label, exact: true }).click()
    await sleep(500);
  }

  // Show source code
  await page.getByRole('radiogroup', { name: 'Preview' }).getByText('Source code').click();
  await sleep(1000);

  // Download the App and save in current folder
  const fname = `my-app-${mode}.zip`
  if (process.env.RUNNER_OS != 'Windows') {
    const downloadPromise = page.waitForEvent('download');
    await page.getByRole('button', { name: 'Download' }).locator('div').click();
    const download = await downloadPromise;
    await page.getByRole('button', { name: 'Close download dialog' }).locator('svg').click();
    await download.saveAs(fname);
    log(`Downloaded file ${fname}\n`);
  } else {
    log(`Skipped download of file ${fname} in Windows\n`);
  }

  await context.close();
  await browser.close();
})();
