const { args, createPage, closePage, takeScreenshot, waitForServerReady, dismissDevmode} = require('./test-utils');

(async () => {
  const arg = args();
  const page = await createPage(arg.headless, arg.ignoreHTTPSErrors);
  await waitForServerReady(page, arg.url);

  await page.evaluate(() =>
    window.localStorage.setItem("vaadin.live-reload.dismissedNotifications","liveReloadUnavailable,preserveOnRefreshWarning")
  );

  await takeScreenshot(page, __filename, 'loaded');
  await page.waitForURL(`${arg.url}login`);
  await page.getByLabel('Username').fill('admin');
  await page.getByLabel('Username').press('Tab');
  await page.getByLabel('Password').first().fill('admin');
  await page.getByLabel('Password').first().press('Tab');
  await page.getByRole('button', { name: 'Log in' }).locator('div').click();
  await takeScreenshot(page, __filename, 'loggedin');
  await page.waitForURL(`${arg.url}`);

  await page.getByRole('link').locator('text=/Personas/').click();
  await takeScreenshot(page, __filename, 'personas');
  await page.waitForURL(`${arg.url}personas`);

  await dismissDevmode(page);
  await takeScreenshot(page, __filename, 'dismissed');

  await page.getByRole('button', { name: '+' }).locator('div').click();
  await takeScreenshot(page, __filename, 'new');
  await page.waitForURL(`${arg.url}personas/new`);

  await page.locator('.detail').getByLabel('First Name').click();
  await page.locator('.detail').getByLabel('First Name').fill('FOOBAR');
  await page.locator('.detail').getByLabel('First Name').press('Tab');
  await page.locator('.detail').getByLabel('Last Name').fill('BAZ');
  await page.locator('.detail').getByLabel('Last Name').press('Tab');
  await page.locator('.detail').getByLabel('First Name').click();
  await page.locator('.detail').getByLabel('Email').press('Escape');
  await takeScreenshot(page, __filename, 'escape');

  await page.evaluate(() => window.location.reload());
  await takeScreenshot(page, __filename, 'reload');
  await page.waitForURL(`${arg.url}personas/new`);

  await page.getByRole('button', { name: 'No' }).locator('div').click();
  await takeScreenshot(page, __filename, 'clicked-no');
  const name = await page.locator('.detail').getByLabel('First Name').inputValue();
  if (name != 'FOOBAR') throw new Error();

  await closePage(page);
})();
