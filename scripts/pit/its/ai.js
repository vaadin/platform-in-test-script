const { log, args, createPage, closePage, takeScreenshot, waitForServerReady, dismissDevmode } = require('./test-utils');

(async () => {
    const arg = args();

    const page = await createPage(arg.headless);
    const sleep = ms => new Promise(r => setTimeout(r, ms));

    await waitForServerReady(page, arg.url, arg);

    // Dismiss dev mode notification if present
    await dismissDevmode(page);
    await takeScreenshot(page, arg, __filename, 'page-loaded');

    log('Testing AI form filling functionality');
    await page.getByLabel('Input Text').fill('Jose Macias Pajas\t\t\tFactura / Invoice\t\t\nNIF: 111222333-S\t \t\t\tFecha / Date\t25 jul 2021\nEU VAT: FR111222333S\t\t\t\tFact.Núm / Invoice #\t12345\nIrlandeses, 7\t \t\t\t\t\n28800, AH, MAD, ES\t\t\t\t\t\n(+34) 653454512\n\t\t\t\t\t\nPara / Bill for\t\t\t\t\t\nPickup Oy\t\t\t\t\t\nFI3456\nRoad Ji 2-4\t\t\t\t\t\nHelsinki, Finland. FI.\t\t\t\t\t\n\t\t\t\t\t\nDescripción / Description\t\t\tCant. / Q.\tPrecio / Rate\tImporte / Amount\n\t\t\t\t\t\nSoftware Development Services\t\t\t1\t3.000,00 €\t3.000,00 €\n\t\t\t\t\t\nInternet Connection costs\t\t\t1\t13,89 €\t13,89 €\n\t\t\t\t\t\nHealth Insurance costs\t\t\t1\t40,16 €\t40,16 €\n\t\t\t\t\t\nTrips & Extra costs\t\t\t1\t\t50,00 €\n\t\t\t\t\t\n\t\t\t\tVAT\t50 €\n\t\t\t\tTotal\t7.439,05 €\n\t\t\t\t\t\nE-mail: aaa@example.org\t\t\t\t\t');
    await takeScreenshot(page, arg, __filename, 'form-text-filled');

    await page.getByRole('button', { name: 'Fill the form' }).locator('span').nth(1).click();
    await takeScreenshot(page, arg, __filename, 'fill-form-clicked');

    log('Waiting for AI to process and fill the form');
    await new Promise(async (resolve, reject) => {
        for (let i=1; i<10; i++) {
            const txt = await page.getByLabel('Order total').inputValue();
            if (txt == '7439.05') {
                log('AI form filling completed successfully');
                await takeScreenshot(page, arg, __filename, 'ai-form-filled');
                resolve('ok');
                return;
            }
            await sleep(3000);
        }
        reject('timeout');
    });

    log('AI test completed successfully');
    await closePage(page, arg);
})();
