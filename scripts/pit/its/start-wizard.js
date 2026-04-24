const { args, createPage, closePage, takeScreenshot } = require('./test-utils');

(async () => {
  const arg = args();
  const log = s => process.stderr.write(`   ${s}`);

  const browser = (await (require('playwright')).chromium.launch({
    headless: arg.headless,
    chromiumSandbox: false
  }));
  const context = await browser.newContext();
  const page = await context.newPage();
  page.setViewportSize({width: 811, height: 1224});
  page.browser = browser;

  page.on('console', msg => console.log("> CONSOLE:", (msg.text() + ' - ' + msg.location().url).replace(/\s+/g, ' ')));
  page.on('pageerror', err => console.log("> PAGEERROR:", ('' + err).replace(/\s+/g, ' ')));

  try {
    await page.goto(`http://${arg.host}:${arg.port}/`);
    await page.waitForTimeout(2000);
    await takeScreenshot(page, arg, __filename, 'home');

    // Verify the wizard loaded
    log(`Checking wizard loaded\n`);
    await page.getByText('Generate Starter Project').waitFor({timeout: 30000});
    log(`Wizard loaded\n`);

    // Verify sample view toggle is present
    const sampleView = page.getByText('Include sample view');
    await sampleView.waitFor({timeout: 10000});
    log(`Sample view toggle found\n`);

    // Expand project settings
    log(`Expanding project settings\n`);
    await page.getByText('Configure Project Settings').click();
    await page.waitForTimeout(1000);
    await takeScreenshot(page, arg, __filename, 'settings-expanded');

    // Download the App
    const fname = `my-app-${arg.mode}.zip`
    if (arg.mode == 'dev' && process.env.RUNNER_OS != 'Windows') {
      log(`Downloading project\n`);
      const downloadPromise = page.waitForEvent('download');
      await page.getByRole('button', { name: 'Download' }).click();
      const download = await downloadPromise;
      await download.saveAs(fname);
      log(`Downloaded file ${fname}\n`);
    } else {
      log(`Skipped download of file ${fname} in Windows\n`);
    }

    await takeScreenshot(page, arg, __filename, 'done');
    await closePage(page, arg);
  } catch (e) {
    await takeScreenshot(page, arg, __filename, 'error');
    await context.close();
    await browser.close();
    throw e;
  }
})();
