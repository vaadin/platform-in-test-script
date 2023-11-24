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
  const log = s => process.stderr.write(`   ${s}`);

  const context = await browser.newContext();
  context.setDefaultTimeout(90000);
  context.setDefaultNavigationTimeout(90000)

  const page = await context.newPage();
  page.setViewportSize({width: 811, height: 1224});

  page.on('console', msg => console.log("> CONSOLE:", (msg.text() + ' - ' + msg.location().url).replace(/\s+/g, ' ')));
  page.on('pageerror', err => console.log("> PAGEERROR:", ('' + err).replace(/\s+/g, ' ')));

  await page.goto(`http://${host}:${port}/`);

  // Start a new project
  log(`Starting new project\n`);
  await page.getByRole('button', { name: 'Get Started' }).click();
  await page.getByText('Start a Project').click();
  await page.locator('body').click();

  // Test example views
  log(`Testing demo views\n`);
  await page.frameLocator('iframe[title="Preview"]').getByLabel('Your name').click();
  await page.frameLocator('iframe[title="Preview"]').getByLabel('Your name').fill('Manolo');
  await page.getByText('About', { exact: true }).click();

  // Add all possible views
  const views = [
    'Dashboard',
    'Feed',
    'Data Grid',
    'Master-Detail',
    'Collaborative Master-Detail',
    'Person Form',
    'Address Form',
    'Credit Card Form',
    'Map',
    // 'Spreadsheet',
    'Chat',
    'Page Editor',
    'Image Gallery',
    'Checkout Form',
    'Grid with Filters',
  ];
  for (const label of views) {
    await page.locator('#newView').click();
    await page.getByRole('heading', { name: label, exact: true }).click();
    await page.getByRole('button', { name: 'Add View' }).click();
    await page.getByRole('textbox', { name: 'Name' }).press('Escape');
    await page.waitForTimeout(500);
    log(`Created view ${label}\n`);
  }

  // TODO (selectors dont work): Change Colors
  // await page.locator('#theme-tab').click();
  // await page.getByRole('button', { name: 'Color' }).click();
  // await page.getByText('Dark').click();
  // await page.locator('[id="colors\\.base"] span').click();
  // await page.locator('#saturation').click();
  // await page.locator('#hue').click();
  // await page.locator('#saturation').click();
  // await page.locator('#saturation').press('Escape');
  // await page.waitForTimeout(1000000)

  // Navigate Views from the generated app menu
  const routes = ['Hello World', 'About', ...views];
  for (const label of routes) {
    await page.frameLocator('iframe[title="Preview"]').getByLabel('Menu toggle').click();
    await page.frameLocator('iframe[title="Preview"]').getByRole('link', { name: label, exact: true }).click();
    await page.waitForTimeout(500);
    log(`Visited view ${label}\n`);
  }

  // close the login to save dialog, that is covering the menu toggle
  await page.getByLabel('Close').click();
  log(`Closed login to save\n`);

  // Show source code
  await page.getByRole('radiogroup').locator('vaadin-icon[icon="vaadin:code"]').click();
  await page.waitForTimeout(1000)
  log(`Clicked code button\n`);

  // Download the App and save in current folder
  const fname = `my-app-${mode}.zip`
  if (mode == 'dev' && process.env.RUNNER_OS != 'Windows') {
    log(`Downloading project\n`);
    await page.getByRole('button', { name: 'Export Project' }).click();
    const downloadPromise = page.waitForEvent('download');
    await page.getByRole('button', { name: 'Download' }).click();
    const download = await downloadPromise;
    await download.saveAs(fname);
    log(`Downloaded file ${fname}\n`);
    await page.getByLabel('Close download dialog').click();
  } else {
    log(`Skipped download of file ${fname} in Windows\n`);
  }

  await context.close();
  await browser.close();
})();
