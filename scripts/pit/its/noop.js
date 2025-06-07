
const {log, dismissDevmode, args, createPage, closePage, takeScreenshot, waitForServerReady} = require('./test-utils');

(async () => {
  const arg = args();
  const page = await createPage(arg.headless, arg.ignoreHTTPSErrors);
  await waitForServerReady(page, arg.url);

  await page.waitForSelector('#outlet > * > *:not(style):not(script)');
  await takeScreenshot(page, __filename, 'view-loaded');
  if (arg.mode == 'dev') {
    dismissDevmode(page);
    await takeScreenshot(page, __filename, 'dismissed-dev');
  }
  const txt = await page.locator('#outlet').first().innerHTML();
  log(txt);
  await closePage(page);
})();
