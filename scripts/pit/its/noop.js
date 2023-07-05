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

  const context = await browser.newContext();

  const page = await context.newPage();
  page.on('console', msg => console.log("> CONSOLE:", msg.text()));
  page.on('pageerror', err => console.log("> JSERROR:", err));

  await page.goto(`http://${host}:${port}/`);

  await page.waitForSelector('#outlet > *');
  const txt = await page.locator('#outlet').first().innerHTML();
  console.log('\n====== PAGE CONTENT ======\n', txt, '\n====== END ======\n');

  await context.close();
  await browser.close();
})();
