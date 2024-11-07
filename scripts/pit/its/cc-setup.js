const { chromium } = require('playwright');

let headless = false, host = 'localhost', port = '8000', hub = false;
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
  const log = s => process.stderr.write(`   ${s}`);

  // Open new page
  const page = await context.newPage();
  page.on('console', msg => console.log("> CONSOLE:", (msg.text() + ' - ' + msg.location().url).replace(/\s+/g, ' ')));
  page.on('pageerror', err => console.log("> PAGEERROR:", ('' + err).replace(/\s+/g, ' ')));

  // Go to http://${host}:${port}/
  await page.goto(`http://${host}:${port}/`);

  if(process.env.PASS_KEY) {
    // Enter the passKey
    await page.getByLabel('Passkey').fill(process.env.PASS_KEY)
    await page.getByRole('button', {name: 'Next'}).click()

    await page.locator('input[type="text"]').fill('keycloak-local.alcala.org');
    await page.getByRole('button', {name: 'Next'}).click()

    await page.getByLabel('First Name').fill('John')
    await page.getByLabel('Last Name').fill('Doe')
    await page.getByLabel('E-mail Address').fill('john.doe@gmail.com')
    await page.getByLabel('Password', {exact: true}).fill('test123')
    await page.getByRole('button', {name: 'Next'}).click()

    await page.getByRole('button', {name: 'Install Control Center'}).click()

  } else {
    log(`Skipping the setup of Control center because of missing env variable: PASS_KEY\n`)
  }
  // ---------------------
  await context.close();
  await browser.close();
})();
