const { expect} = require('@playwright/test');
const {log, run, args, createPage, closePage, takeScreenshot, waitForServerReady} = require('./test-utils');

(async () => {
    const arg = args();
    if (!arg.login) {
        log(`Skipping the setup of Control center because of missing --email= parameter\n`)
        process.exit(1);
    }
    if (!arg.tmppass) {
        arg.tmppass = await run(`kubectl -n control-center get secret control-center-user -o go-template="{{ .data.password | base64decode | println }}"`);
    }

    const page = await createPage(arg.headless, arg.ignoreHTTPSErrors);

    await waitForServerReady(page, arg.url);
    await page.locator('html').first().innerHTML();

    await takeScreenshot(page, __filename, 'view-before-loaded');
    await expect(page.getByLabel('Email')).toBeVisible();
    await takeScreenshot(page, __filename, 'view-after-loaded');

    log(`login with user ${arg.login} and password ${arg.tmppass}`);
    await page.getByLabel('Email').fill(arg.login);
    await page.getByLabel('Password').fill(arg.tmppass);
    await page.getByRole('button', {name: 'Sign In'}).click()

    await takeScreenshot(page, __filename, 'logged-in');

    const newsPass = page.getByLabel('New Password');
    if (await newsPass.count() == 0) {
        log("Seems that CC was already setup trying to login")
        await page.getByLabel('Email').fill(arg.login);
        await page.getByLabel('Password').fill(arg.pass);
        await page.getByRole('button', {name: 'Sign In'}).click()
        await takeScreenshot(page, __filename, 'logged-in');
    } else {
        await newsPass.fill(arg.pass);
        await page.getByLabel('Confirm Password').fill(arg.pass);
        await page.getByRole('button', { name: 'Submit' }).click();

        await takeScreenshot(page, __filename, 'password-changed');

        await page.getByLabel('First Name').fill(arg.login.split('@')[0]);
        await page.getByLabel('Last Name').fill(arg.login.split('@')[1]);
        await page.getByRole('button', { name: 'Submit' }).click();
        await takeScreenshot(page, __filename, 'user-configured');
        await waitForServerReady(page, arg.url);
        await page.getByRole('button', { name: 'Manage applications' }).click();
    }

    await page.getByRole('listitem').filter({ hasText: 'Settings'}).click()
    await expect(page.getByRole('heading', { name: 'Applications' })).toBeVisible();
    await closePage(page);
    })();