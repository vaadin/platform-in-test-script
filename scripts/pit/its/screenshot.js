const {log, dismissDevmode, args, createPage, closePage, takeScreenshot, waitForServerReady} = require('./test-utils');

(async () => {
  const arg = args();

  if (!arg.prefix) {
    log('Error: Debe proporcionar un prefijo usando --prefix=<nombre>');
    process.exit(1);
  }

  let url = arg.url;
  let sel = '#outlet > * > *:not(style):not(script)';
  if (arg.name === 'start') {
    url += 'app/p';
    sel = 'app-view';
  }
  const page = await createPage(arg.headless, arg.ignoreHTTPSErrors);
  await waitForServerReady(page, url, arg);
  await page.waitForSelector(sel);

  await takeScreenshot(page, arg, __filename, 'screenshot');
  await closePage(page, arg);
})();
