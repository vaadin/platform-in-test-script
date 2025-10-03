const { chromium } = require('playwright');
// When using playwright in lib mode we cannot use expect, thus we use regular asserts
const assert = require('assert');

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
  const browser1 = await chromium.launch({
    headless: headless,
    chromiumSandbox: true
  });

  const browser2 = await chromium.launch({
    headless: headless,
    chromiumSandbox: true
  });

  // TODO: should work with smaller viewport too like in 24.9
  const context1 = await browser1.newContext({
    viewport: { width: 1920, height: 1080 }
  });
  const page1 = await context1.newPage();
  page1.on('console', msg => console.log("> PAGE1 CONSOLE:", (msg.text() + ' - ' + msg.location().url).replace(/\s+/g, ' ')));
  page1.on('pageerror', err => console.log("> PAGE1 PAGEERROR:", ('' + err).replace(/\s+/g, ' ')));

  await page1.goto(`http://${host}:${port}/`);

  // TODO: should work with smaller viewport too like in 24.9
  const context2 = await browser2.newContext({
    viewport: { width: 1920, height: 1080 }
  });
  const page2 = await context2.newPage();
  page2.on('console', msg => console.log("> PAGE2 CONSOLE:", (msg.text() + ' - ' + msg.location().url).replace(/\s+/g, ' ')));
  page2.on('pageerror', err => console.log("> PAGE2 PAGEERROR:", ('' + err).replace(/\s+/g, ' ')));

  await page2.goto(`http://${host}:${port}/`);

  /*
  This script tests the collaboration view from Vaadin Start. 
  First, it has two users trying to chat in a channel. Second, it check whether the avatars are properly displayed.
  Third, it tests two users taking turns on editing one entry in the master-detail view.
  */


  //send a message
  await page1.getByText('#support').click();
  await page1.getByText('#casual').click();
  await page1.getByText('#general').click();
  await page1.getByLabel('Message').click();
  await page1.getByLabel('Message').fill('Test from user 1');
  await page1.getByRole('button', { name: 'Send' }).click();

  //check if user 2 received it and reply
  await page2.getByText('#general').click();
  await page2.getByText('Test from user 1');
  await page2.getByLabel('Message').click();
  await page2.getByLabel('Message').fill('Test from user 2');
  await page2.getByRole('button', { name: 'Send' }).click();

  //check if user1 received answer
  await page1.getByText('Test from user 2');

  //Check avatar groups:
  //There is always one more avatar in the group than there are users (which displays 
  //the number of non-visible 'other' avatars, i.e., the overflow.) It is invisible in our case.
  let expectedAvatarCount = 2+1;

  const avatarCount1 = await page1.locator('vaadin-avatar-group > vaadin-avatar').count();
  assert(avatarCount1 === expectedAvatarCount, "Expected two users but found: "+(avatarCount1-1));

  const avatarCount2 = await page2.locator('vaadin-avatar-group > vaadin-avatar').count();
  assert(avatarCount2 === expectedAvatarCount, "Expected two users but found: "+(avatarCount2-1));

  //edit one entry as user 1
  await page1.getByRole('link', { name: 'Master Detail' }).click();
  await page1.getByText('Gene', { exact: true }).click();
  await page1.waitForTimeout(1000);
  await page1.getByLabel('First Name', { exact: true }).click();
  await page1.getByLabel('First Name', { exact: true }).fill('Gene James');
  await page1.getByRole('button', { name: 'Save' }).click();
  //wait for the notification of data updated (the count is only there for the promise to be resolved)
  await page1.getByRole('alert').count();

  //check if changes appear for user 2
  await page2.getByRole('link', { name: 'Master Detail' }).click();

  await page1.waitForTimeout(1000);
  await page2.waitForTimeout(1000);
  await page1.reload();
  await page2.reload();

  await page2.getByText('Gene James', { exact: true }).click();
  await page1.waitForTimeout(1000);
  await page2.getByLabel('First Name', { exact: true }).fill('Gene James, 3rd');
  await page2.getByRole('button', { name: 'Save' }).click();
  //wait for the notification of data updated
  await page2.getByRole('alert').count();

  await page1.waitForTimeout(1000);
  await page2.waitForTimeout(1000);
  await page1.reload();
  await page2.reload();

  await page1.getByText('Gene James, 3rd', { exact: true }).click();

  await context1.close();
  await browser1.close();

  await context2.close();
  await browser2.close();
})();