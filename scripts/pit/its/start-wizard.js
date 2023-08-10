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

  const page = await context.newPage();
  page.on('console', msg => console.log("> CONSOLE:", (msg.text() + ' - ' + msg.location().url).replace(/\s+/g, ' ')));
  page.on('pageerror', err => console.log("> PAGEERROR:", ('' + err).replace(/\s+/g, ' ')));

  await page.goto(`http://${host}:${port}/`);
  
  await page.getByRole('button', { name: 'Close Tour' }).click();
  await page.frameLocator('iframe[title="Preview"]').getByLabel('Your name').click();
  await page.frameLocator('iframe[title="Preview"]').getByLabel('Your name').fill('Manolo');
  const downloadPromise = page.waitForEvent('download');
  await page.getByRole('button', { name: 'Download' }).locator('div').click();
  const download = await downloadPromise;
  await page.getByRole('button', { name: 'Close download dialog' }).locator('svg').click();
  const fname = `my-app-${mode}.zip`
  await download.saveAs(fname);
  log(`Downloaded file ${fname}\n`);

  await context.close();
  await browser.close();
})();
