const { log, args, createPage, closePage, takeScreenshot, waitForServerReady, execCommand, compileAndReload } = require('./test-utils');

(async () => {
    const arg = args();

    const page = await createPage(arg.headless, arg.ignoreHTTPSErrors);

    await waitForServerReady(page, arg.url);
    await takeScreenshot(page, __filename, 'page-loaded');

    await page.locator('text=Click me').click({timeout:90000});
    await page.locator('text=Clicked');
    await takeScreenshot(page, __filename, 'initial-click');

    if (arg.mode == 'prod') {
        log("Skipping hotswap checks for production mode");
    } else {
        const java = (await execCommand('find src -name MainView.java')).stdout.trim();
        log(`Changing ${java} and Compiling ...`);

        await execCommand(`perl -pi -e s/Click/Foo/g ${java}`);
        await compileAndReload(page, arg.url, { name: arg.name });
        await takeScreenshot(page, __filename, 'after-compile-foo');

        await page.locator('text=Foo me').click({timeout:90000});
        const foo = await page.locator('text=Fooed').textContent();
        log(`Ok (${foo})`);
        await takeScreenshot(page, __filename, 'foo-clicked');

        log(`Restoring ${java} and Compiling ...`);

        await execCommand(`git checkout ${java}`)
        await compileAndReload(page, arg.url, { name: arg.name });
        await takeScreenshot(page, __filename, 'after-restore-compile');

        await page.locator('text=Click me').click({timeout:90000});
        const click = await page.locator('text=Clicked').textContent();
        log(`Ok (${click})`);
        await takeScreenshot(page, __filename, 'restored-click');
    }

    await closePage(page);
})();
