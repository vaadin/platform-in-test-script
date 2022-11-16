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
  await page.goto('http://localhost:8080/login');
  await page.evaluate(() =>
    window.localStorage.setItem("vaadin.live-reload.dismissedNotifications","liveReloadUnavailable,preserveOnRefreshWarning")
  );
  await page.getByText('click here').click();
  await page.waitForURL('http://localhost:8080/login');

  await page.getByLabel('Username').fill('admin');
  await page.getByLabel('Username').press('Tab');
  await page.getByLabel('Password').fill('admin');
  await page.getByLabel('Password').press('Tab');
  await page.getByRole('button', { name: 'Log in' }).locator('div').click();
  await page.waitForURL('http://localhost:8080/');
  await page.getByRole('link', { name: ' Personas' }).click();
  await page.waitForURL('http://localhost:8080/personas');
  await page.getByRole('button', { name: '+' }).locator('div').click();
  await page.waitForURL('http://localhost:8080/personas/new');
  await page.getByLabel('First Name').click();
  await page.getByLabel('First Name').fill('FOOBAR');
  await page.getByLabel('First Name').press('Tab');
  await page.getByLabel('Last Name').fill('BAZ');
  await page.getByLabel('Last Name').press('Tab');
  await page.getByLabel('First Name').click();
  await page.getByLabel('Email').press('Escape');
  await page.evaluate(() => window.location.reload());  
  await page.waitForURL('http://localhost:8080/personas/new');
  await page.getByRole('button', { name: 'No' }).locator('div').click();

  const name = await page.getByLabel('First Name').inputValue();
  if (name != 'FOOBAR') throw new Error();

  await context.close();
  await browser.close();
})();
