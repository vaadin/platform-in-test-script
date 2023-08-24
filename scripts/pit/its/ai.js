const { chromium } = require('playwright');
// const { test, expect } = require('@playwright/test');

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
  page.on('console', msg => console.log("> CONSOLE:", (msg.text() + ' - ' + msg.location().url).replace(/\s+/g, ' ')));
  page.on('pageerror', err => console.log("> PAGEERROR:", ('' + err).replace(/\s+/g, ' ')));

  await page.goto(`http://${host}:${port}/`);

  await page.getByLabel('Input Text').fill('Jose Macias Pajas\t\t\tFactura / Invoice\t\t\nNIF: 111222333-S\t \t\t\tFecha / Date\t25 jul 2021\nEU VAT: FR111222333S\t\t\t\tFact.Núm / Invoice #\t12345\nIrlandeses, 7\t \t\t\t\t\n28800, AH, MAD, ES\t\t\t\t\t\n(+34) 653454512\n\t\t\t\t\t\nPara / Bill for\t\t\t\t\t\nPickup Oy\t\t\t\t\t\nFI3456\nRoad Ji 2-4\t\t\t\t\t\nHelsinki, Finland. FI.\t\t\t\t\t\n\t\t\t\t\t\nDescripción / Description\t\t\tCant. / Q.\tPrecio / Rate\tImporte / Amount\n\t\t\t\t\t\nSoftware Development Services\t\t\t1\t3.000,00 €\t3.000,00 €\n\t\t\t\t\t\nInternet Connection costs\t\t\t1\t13,89 €\t13,89 €\n\t\t\t\t\t\nHealth Insurance costs\t\t\t1\t40,16 €\t40,16 €\n\t\t\t\t\t\nTrips & Extra costs\t\t\t1\t\t50,00 €\n\t\t\t\t\t\n\t\t\t\tVAT\t50 €\n\t\t\t\tTotal\t7.439,05 €\n\t\t\t\t\t\nE-mail: aaa@example.org\t\t\t\t\t');
  await page.getByRole('button', { name: 'Fill the form' }).locator('span').nth(1).click();

  await new Promise(async (resolve, reject) => {
    for (let i=1; i<10; i++) {
      const txt = await page.getByLabel('Order total').inputValue();
      if (txt == '7439.05') {
        resolve('ok');
        return;
      }
      await sleep(3000);
    }
    reject('timeout');
  });

  await context.close();
  await browser.close();
})();
