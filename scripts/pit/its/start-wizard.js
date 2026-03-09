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
    await takeScreenshot(page, arg, __filename, 'home');

    // Start a new project
    log(`Starting new project\n`);
    await page.getByText(/Start (a Project|Playing)/).click();
    await page.keyboard.press('Escape');
    await takeScreenshot(page, arg, __filename, 'project-started');

    // Add all possible views
    const views = [
      'Dashboard',
      'Feed',
      'Data Grid',
      'Master-Detail',
      'Collaborative Master-Detail',
      'Person Form',
      'Address Form',
      'Credit Card Form',
      'Map',
      // 'Spreadsheet',
      'Chat',
      'Page Editor',
      'Image Gallery',
      'Checkout Form',
      'Grid with Filters',
    ];
    for (const label of views) {
      log(`${label} creating view\n`);
      await page.locator('#newView').click();
      await page.waitForTimeout(500);
      const viewLabel = await page.getByRole('heading', { name: label, exact: true });
      if (!await viewLabel.isVisible()) {
        await page.getByRole('heading', { name: 'Flow (Java)' }).click();
      }
      log(`${label} clicking on ${viewLabel}\n`);
      await viewLabel.click();
      const addViewButton  = page.getByLabel('Add view').getByRole('button', { name: 'Add View' });

      log(`${label} clicking on ${addViewButton}\n`);
      await addViewButton.click();
      let newViewNameTextBox = page.getByRole('textbox', { name: 'Name' });
      if (await newViewNameTextBox.isVisible()) {
        log(`pushing escape on ${newViewNameTextBox} for ${label}\n`);
        await newViewNameTextBox.press('Escape');
      } else {
        log(`${label} not visible ${newViewNameTextBox} sleeping 5sec\n`);
        await page.waitForTimeout(5000);
        newViewNameTextBox = page.getByRole('textbox', { name: 'Name' });
        if (await newViewNameTextBox.isVisible()) {
          log(`pushing escape on ${newViewNameTextBox} for ${label}\n`);
          await newViewNameTextBox.press('Escape');
        } else {
          log(`let's see if fails ....`)
        }
      }

      await page.waitForTimeout(1000);
      log(`Created view ${label}\n`);
    }
    await takeScreenshot(page, arg, __filename, 'all-views-created');

    // close the login to save dialog, that is covering the menu toggle
    await page.getByLabel('Close')
      // in 24.4 there is no close button, so we click the eye icon to continue
      .or(page.locator('vaadin-radio-button').locator('vaadin-icon[icon="lumo:eye"]'))
      .first().click();
    log(`Closed login to save\n`);

    // Show source code
    await page.getByRole('radiogroup').locator('vaadin-icon[icon="vaadin:code"]').click();
    await page.waitForTimeout(1000)
    log(`Clicked code button\n`);
    await takeScreenshot(page, arg, __filename, 'code-shown');

    // Download the App and save in current folder
    const fname = `my-app-${arg.mode}.zip`
    if (arg.mode == 'dev' && process.env.RUNNER_OS != 'Windows') {
      log(`Downloading project\n`);
      await page.getByRole('button', { name: 'Download Project' }).click();
      const downloadPromise = page.waitForEvent('download');
      await page.getByRole('button', { name: 'Download', exact: true }).click();
      const download = await downloadPromise;
      await download.saveAs(fname);
      log(`Downloaded file ${fname}\n`);
      await page.getByLabel('Close download dialog').click();
    } else {
      log(`Skipped download of file ${fname} in Windows\n`);
    }

    await closePage(page, arg);
  } catch (e) {
    await takeScreenshot(page, arg, __filename, 'error');
    await context.close();
    await browser.close();
    throw e;
  }
})();
