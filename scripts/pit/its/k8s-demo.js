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
  page.on('console', msg => console.log("> CONSOLE:", msg.text()));
  page.on('pageerror', err => console.log("> JSERROR:", err));

  await page.goto(`http://${host}:${port}/login`);
  await page.evaluate(() =>
    window.localStorage.setItem("vaadin.live-reload.dismissedNotifications","liveReloadUnavailable,preserveOnRefreshWarning")
  );
  await page.getByText('click here').click();
  await page.waitForURL(`http://${host}:${port}/login`);

  await page.getByLabel('Username').fill('admin');
  await page.getByLabel('Username').press('Tab');
  await page.getByLabel('Password').first().fill('admin');
  await page.getByLabel('Password').first().press('Tab');
  await page.getByRole('button', { name: 'Log in' }).locator('div').click();
  await page.waitForURL(`http://${host}:${port}/`);
  await page.getByRole('link', { name: ' Personas' }).click();
  await page.waitForURL(`http://${host}:${port}/personas`);
  await page.getByRole('button', { name: '+' }).locator('div').click();
  await page.waitForURL(`http://${host}:${port}/personas/new`);
  await page.locator('.detail').getByLabel('First Name').click();
  await page.locator('.detail').getByLabel('First Name').fill('FOOBAR');
  await page.locator('.detail').getByLabel('First Name').press('Tab');
  await page.locator('.detail').getByLabel('Last Name').fill('BAZ');
  await page.locator('.detail').getByLabel('Last Name').press('Tab');
  await page.locator('.detail').getByLabel('First Name').click();
  await page.locator('.detail').getByLabel('Email').press('Escape');
  await page.evaluate(() => window.location.reload());
  await page.waitForURL(`http://${host}:${port}/personas/new`);
  await page.getByRole('button', { name: 'No' }).locator('div').click();

  const name = await page.locator('.detail').getByLabel('First Name').inputValue();
  if (name != 'FOOBAR') throw new Error();

  await context.close();
  await browser.close();
})();
