const { log, args, createPage, closePage, takeScreenshot, waitForServerReady, dismissDevmode } = require('./test-utils');

(async () => {
    const arg = args();

    const page = await createPage(arg.headless);
    page.setViewportSize({width: 811, height: 1224});

    await waitForServerReady(page, arg.url);
    await takeScreenshot(page, __filename, 'wizard-loaded');

    // Start a new project
    log(`Starting new project`);
    await page.getByText(/Start (a Project|Playing)/).click();
    await page.keyboard.press('Escape');
    await takeScreenshot(page, __filename, 'project-started');

  // No demo view anymore
  // Test example views
  // log(`Testing demo views\n`);
  // await page.frameLocator('iframe[title="Preview"]').getByLabel('Your name').click();
  // await page.frameLocator('iframe[title="Preview"]').getByLabel('Your name').fill('Manolo');
  // await page.getByText('About', { exact: true }).click();

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

    // const addViewButton = page.getByRole('button', { name: 'Add View' });
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

  // TODO (selectors dont work): Change Colors
  // await page.locator('#theme-tab').click();
  // await page.getByRole('button', { name: 'Color' }).click();
  // await page.getByText('Dark').click();
  // await page.locator('[id="colors\\.base"] span').click();
  // await page.locator('#saturation').click();
  // await page.locator('#hue').click();
  // await page.locator('#saturation').click();
  // await page.locator('#saturation').press('Escape');
  // await page.waitForTimeout(1000000)

  // TODO (selectors changed): Navigate Views from the generated app menu
  // const routes = ['Hello World', 'About', ...views];
  // for (const label of routes) {
  //   await page.frameLocator('iframe[title="Preview"]').getByLabel('Menu toggle').click();
  //   await page.frameLocator('iframe[title="Preview"]').getByRole('link', { name: label, exact: true }).click();
  //   await page.waitForTimeout(500);
  //   log(`Visited view ${label}\n`);
  // }


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

  // Download the App and save in current folder
  const fname = `my-app-${mode}.zip`
  if (mode == 'dev' && process.env.RUNNER_OS != 'Windows') {
    log(`Downloading project\n`);
    await page.getByRole('button', { name: 'Download Project' }).click();
    const downloadPromise = page.waitForEvent('download');
    await page.getByRole('button', { name: 'Download', exact: true }).click();
    const download = await downloadPromise;
    await download.saveAs(fname);
    log(`Downloaded file ${fname}`);
    await page.getByLabel('Close download dialog').click();
    await takeScreenshot(page, __filename, 'download-completed');
  } else {
    log(`Skipped download of file ${fname} in Windows`);
  }

  log('Wizard testing completed successfully');
  await closePage(page);
})();
