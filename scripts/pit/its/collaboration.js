const { expect } = require('@playwright/test');
const { log, args, createPage, closePage, takeScreenshot, waitForServerReady, dismissDevmode } = require('./test-utils');

(async () => {
    const arg = args();

    log('Starting collaboration test with two browser instances');

    // Create two separate pages for collaboration testing
    const page1 = await createPage(arg.headless);
    const page2 = await createPage(arg.headless);

    // TODO: should work with smaller viewport too like in 24.9
    // The createPage function already sets viewport to 1792x970, which should be sufficient
    
    await waitForServerReady(page1, arg.url);
    await waitForServerReady(page2, arg.url);

    // Dismiss dev mode notifications if present
    await dismissDevmode(page1);
    await dismissDevmode(page2);
    await takeScreenshot(page1, __filename, 'page1-loaded');
    await takeScreenshot(page2, __filename, 'page2-loaded');

    /*
    This script tests the collaboration view from Vaadin Start. 
    First, it has two users trying to chat in a channel. Second, it check whether the avatars are properly displayed.
    Third, it tests two users taking turns on editing one entry in the master-detail view.
    */

    log('Testing chat functionality between two users');

    //send a message
    await page1.getByText('#support').click();
    await page1.getByText('#casual').click();
    await page1.getByText('#general').click();
    await page1.getByLabel('Message').click();
    await page1.getByLabel('Message').fill('Test from user 1');
    await page1.getByRole('button', { name: 'Send' }).click();
    await takeScreenshot(page1, __filename, 'user1-sent-message');

    //check if user 2 received it and reply
    await page2.getByText('#general').click();
    await page2.getByText('Test from user 1');
    await page2.getByLabel('Message').click();
    await page2.getByLabel('Message').fill('Test from user 2');
    await page2.getByRole('button', { name: 'Send' }).click();
    await takeScreenshot(page2, __filename, 'user2-sent-reply');

    //check if user1 received answer
    await page1.getByText('Test from user 2');
    await takeScreenshot(page1, __filename, 'user1-received-reply');

    log('Testing avatar groups');

    //Check avatar groups:
    //There is always one more avatar in the group than there are users (which displays 
    //the number of non-visible 'other' avatars, i.e., the overflow.) It is invisible in our case.
    let expectedAvatarCount = 2+1;

    const avatarCount1 = await page1.locator('vaadin-avatar-group > vaadin-avatar').count();
    expect(avatarCount1).toBe(expectedAvatarCount);

    const avatarCount2 = await page2.locator('vaadin-avatar-group > vaadin-avatar').count();
    expect(avatarCount2).toBe(expectedAvatarCount);

    log('Avatar counts verified successfully');

    log('Testing master-detail collaboration');

    //edit one entry as user 1
    await page1.getByRole('link', { name: 'Master Detail' }).click();
    await page1.getByText('Gene', { exact: true }).click();
    await page1.waitForTimeout(1000);
    await page1.getByLabel('First Name', { exact: true }).click();
    await page1.getByLabel('First Name', { exact: true }).fill('Gene James');
    await page1.getByRole('button', { name: 'Save' }).click();
    //wait for the notification of data updated (the count is only there for the promise to be resolved)
    await page1.getByRole('alert').count();
    await takeScreenshot(page1, __filename, 'user1-edited-entry');

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
    await takeScreenshot(page2, __filename, 'user2-edited-entry');

    await page1.waitForTimeout(1000);
    await page2.waitForTimeout(1000);
    await page1.reload();
    await page2.reload();

    await page1.getByText('Gene James, 3rd', { exact: true }).click();
    await takeScreenshot(page1, __filename, 'user1-sees-changes');

    log('Collaboration test completed successfully');

    await closePage(page1);
    await closePage(page2);
})();