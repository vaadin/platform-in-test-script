const { chromium, webkit } = require('playwright');
const screenshots = "screenshots.out"

let headless = false, host = 'localhost', port = '8080', mode = 'prod', name;
process.argv.forEach(a => {
  if (/^--headless/.test(a)) {
    headless = true;
  } else if (/^--port=/.test(a)) {
    port = a.split('=')[1];
  } else if (/^--mode=/.test(a)) {
    mode = a.split('=')[1];
  } else if (/^--name=/.test(a)) {
    name = a.split('=')[1];
  }
});

let sscount = 0;
async function takeScreenshot(page, name) {
  const path = `${screenshots}/${++sscount}-${name}-${mode}.png`;
  await page.screenshot({ path });
  log(`Screenshot taken: ${path}\n`);
}
const log = s => process.stderr.write(`\x1b[1m=> TEST: \x1b[0;33m${s}\x1b[0m`);

(async () => {
  const browser = await chromium.launch({
    headless: headless,
    chromiumSandbox: false
  });
  const context = await browser.newContext();
  const text = 'Greet';

  // Open new page
  const page = await context.newPage();
  page.on('console', msg => console.log("> CONSOLE:", (msg.text() + ' - ' + msg.location().url).replace(/\s+/g, ' ')));
  page.on('pageerror', err => console.log("> PAGEERROR:", ('' + err).replace(/\s+/g, ' ')));

  // Go to http://localhost:8080/
  await page.goto(`http://${host}:${port}/`);

  await takeScreenshot(page, 'initial-view');
  // Click input[type="text"]
  try {
    await page.locator('input[type="text"]').click({timeout:10000});
  } catch (error) {
    // skeleton-starter-flow-cdi wildfly:run sometimes does not load the page correctly
    log(`Error looking for input[type="text"], sleeping and reloading page\n`);
    await page.reload();
    await page.waitForLoadState('load')
    await page.waitForTimeout(10000);
    await takeScreenshot(page, 'initial-view-after-reload');
    await page.locator('input[type="text"]').click({timeout:60000});
  }

  // Fill input[type="text"]
  await page.locator('input[type="text"]').fill(text);

  // Click text=Say hello
  await page.locator('vaadin-button').click();
  await takeScreenshot(page, 'button-clicked');


  // Look for the text, sometimes rendered in an alert, sometimes in the dom
  let m;
  try {
    m = await page.getByRole('alert').nth(1).innerText({timeout:500});
  } catch (e) {
    console.log(`Not Found ${text} in an 'alert' role`);
    m = await page.locator(`text=/${text}/`).innerText({timeout:5000});
  }
  if (! new RegExp(text).test(m)) {
    throw new Error(`${text} text not found in ${m}`);
  }
  console.log(`Found ${m} text in the dom`);

  // Close everything
  // ---------------------
  await context.close();
  await browser.close();
})();
