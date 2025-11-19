const { expect } = require('@playwright/test');
const { log, args, createPage, closePage, takeScreenshot, waitForServerReady, dismissDevmode, execCommand } = require('./test-utils');
// When using playwright in lib mode we cannot use expect, thus we use regular asserts
const assert = require('assert');

const { spawn } = require('child_process');
const fs = require('fs');
const Net = require('net');
const isWin = /^win/.test(process.platform);

let buildCmd, buildArgs;
if (fs.existsSync('mvnw') ) {
  if (isWin) {
    buildCmd = fs.existsSync('mvnw.bat') ? 'mvnw.bat' : 'mvnw.cmd';
  } else {
    buildCmd = './mvnw';
  }
  buildArgs = 'compiler:compile';
} else if (fs.existsSync('gradlew')) {
  if (isWin) {
    buildCmd = fs.existsSync('gradlew.bat') ? 'gradlew.bat' : 'gradlew.cmd';
  } else {
    buildCmd = './gradlew';
  }
  buildArgs = 'compileJava';
} else {
  throw new Error('No build tool found');
}

const compileProject = async () => await execCommand(`${buildCmd} ${buildArgs}`);

async function isPortTaken(port) {
  return new Promise((resolve, reject) => {
    const tester = Net.createServer()
        .once('error', err => resolve(true))
        .once('listening', () => {
          log(`Port ${port} not listening`);
          tester.close();
          resolve(false);
        })
        .listen(port)
  });
}

async function reload(page, url) {
  log(`reloading page`);
  let i = 0;
  while(i++ < 30 && ! await isPortTaken(url.split(':')[2].split('/')[0])) {
    await page.waitForTimeout(2000);
  }
  await page.reload();
  await page.waitForURL(url);
  log(`page reloaded`);
  await takeScreenshot(page, 'initializer.js', 'view-reloaded');
}

async function compile(page, url) {
  log('Re-compiling project');
  await compileProject();
  await page.waitForTimeout(10000);
  await reload(page, url)
}

(async () => {
    const arg = args();

    const page = await createPage(arg.headless, arg.ignoreHTTPSErrors);
    page.setViewportSize({width: 811, height: 1224});

    await waitForServerReady(page, arg.url);
    
    // Dismiss dev mode notification if present
    await dismissDevmode(page);
    
    await page.waitForTimeout(3000);
    await takeScreenshot(page, __filename, 'view-loaded');

    if (arg.mode == 'prod') {
        log("Skipping creating views for production mode");
        const text = page.getByText('Could not navigate');
        assert.ok(await text.isVisible());
    } else {
        const linkText = /react/.test(arg.name) ?
          'Create a view for coding the UI in TypeScript with Hilla and React' :
          'Create a view for coding the UI in Java with Flow';
        const viewName = /react/.test(arg.name) ? '@index.tsx' : 'HomeView.java';

        log(`Creating ${viewName} view using copilot`);
        await page.getByRole('link', { name: linkText }).click();
        await page.waitForTimeout(2000);
        await takeScreenshot(page, __filename, 'view-created');
        await reload(page, arg.url);
        const view = (await execCommand(`find src/main/frontend src/main/java -name '${viewName}'`)).stdout.trim();
        assert.ok(fs.existsSync(view));

        // Compile the application so as spring-devtools watches the changes
        await compile(page, arg.url);

        await takeScreenshot(page, __filename, 'app-compiled');

        // Wait for the frontend to be built
        log(`Checking if the new view is Building`);
        const building = page.getByText('Building');
        if (await building.isVisible()) {
            await takeScreenshot(page, __filename, 'view-building');
            log(`Waiting for frontend to be built ...`)
            while(await building.isVisible()) {
                process.stderr.write(".");
                await page.waitForTimeout(1000);
            }
            console.error('');
        }

        log(`checking if the new view is available`);
        await reload(page, arg.url);
        await page.waitForTimeout(2000);
        await takeScreenshot(page, __filename, 'view-reloaded-after-compiling');

        const text = page.getByText('Welcome');
        assert.ok(await text.isVisible());

        log(`Removing the view ${view}`);
        fs.unlinkSync(view);
    }

    await closePage(page);
})();
