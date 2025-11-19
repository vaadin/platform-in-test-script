const { log, args, createPage, closePage, takeScreenshot, waitForServerReady, execCommand } = require('./test-utils');

const compileMvn = async () => await execCommand(`${/^win/.test(process.platform) ? 'mvn.cmd' : 'mvn'} compiler:compile`);

async function compile(page, name) {
  await compileMvn();
  log('Sleeping 10secs');
  await page.waitForTimeout(10000);

  if (/jetty/.test(name)) {
    log('Reloading Page');
    await page.reload();
    await page.waitForLoadState();
  }
}

(async () => {
    const arg = args();

    const page = await createPage(arg.headless);

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
        await compile(page, arg.name);
        await takeScreenshot(page, __filename, 'after-compile-foo');

        await page.locator('text=Foo me').click({timeout:90000});
        const foo = await page.locator('text=Fooed').textContent();
        log(`Ok (${foo})`);
        await takeScreenshot(page, __filename, 'foo-clicked');

        log(`Restoring ${java} and Compiling ...`);

        await execCommand(`git checkout ${java}`)
        await compile(page, arg.name);
        await takeScreenshot(page, __filename, 'after-restore-compile');

        await page.locator('text=Click me').click({timeout:90000});
        const click = await page.locator('text=Clicked').textContent();
        log(`Ok (${click})`);
        await takeScreenshot(page, __filename, 'restored-click');
    }

    await closePage(page);
})();
