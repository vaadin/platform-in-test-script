const { chromium, webkit } = require('playwright');

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
  const text = 'Greet';

  // Open new page
  const page = await context.newPage();
  page.on('console', msg => console.log("> CONSOLE:", (msg.text() + ' - ' + msg.location().url).replace(/\s+/g, ' ')));
  page.on('pageerror', err => console.log("> PAGEERROR:", ('' + err).replace(/\s+/g, ' ')));

  // Go to http://localhost:8080/
  await page.goto(`http://${host}:${port}/`);

  // Click input[type="text"]
  await page.locator('input[type="text"]').click({timeout:60000});

  // Fill input[type="text"]
  await page.locator('input[type="text"]').fill(text);

  // Click text=Say hello
  await page.locator('vaadin-button').click();

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
