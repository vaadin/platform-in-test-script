const { chromium } = require('playwright');
// When using playwright in lib mode we cannot use expect, thus we use regular asserts
const assert = require('assert');

const { spawn } = require('child_process');
const fs = require('fs');
const isWin = /^win/.test(process.platform);

let buildCmd, buildArgs;
if (fs.existsSync('mvnw') ) {
  if (isWin) {
    buildCmd = fs.existsSync('./mvnw.bat') ? './mvnw.bat' : './mvnw.cmd';
  } else {
    buildCmd = './mvnw';
  }
  buildArgs = 'compiler:compile';
} else if (fs.existsSync('gradlew')) {
  if (isWin) {
    buildCmd = fs.existsSync('./gradlew.bat') ? './gradlew.bat' : './gradlew.cmd';
  } else {
    buildCmd = './gradlew';
  }
  buildArgs = 'compileJava';
} else {
  throw new Error('No build tool found');
}

const compileProject = async () => await exec(`${buildCmd} ${buildArgs}`);
const log = s => process.stderr.write(`\x1b[1m=> TEST: \x1b[0;33m${s}\x1b[0m`);

async function compile(page) {
  log('Re-compiling project\n');
  await compileProject();
  await page.waitForTimeout(10000);
}

async function exec(order, ops) {
  return new Promise((resolve, reject) => {
    const cmd = order.split(/ +/)[0];
    const arg = order.split(/ +/).splice(1);
    log(`Executing -> ${order}\n`);
    let stdout = "", stderr = "";
    const ls = spawn(cmd, arg, { shell: true });
    ls.stdout.on('data', (data) => stdout += data);
    ls.stderr.on('data', (data) => stderr += data);
    ls.on('close', (code) => {
      if (code !== 0) {
        log(`>> ERROR ${code}\n`);
        log(`>> STDOUT\n ${stdout}\n`);
        log(`>> STDERR\n ${stderr}\n`);
        reject({ stdout, stderr, code });
      } else {
        resolve({ stdout, stderr, code });
      }
    });
  });
}

let headless = false, host = 'localhost', port = '8080', mode = 'prod', name;
process.argv.forEach(a => {
  if (/^--headless/.test(a)) {
    headless = true;
  } else if (/^--port=/.test(a)) {
    port = a.split('=')[1];
  } else if (/^--mode=/.test(a)) {
    mode = a.split('=')[1];
  } else if (/^--name=/.test(a)) {
    name = a.split('=')[1];
  }
});

(async () => {

  const browser = await chromium.launch({
    headless: headless,
    chromiumSandbox: false
  });
  const context = await browser.newContext();


  const page = await context.newPage();
  page.setViewportSize({width: 811, height: 1224});

  page.on('console', msg => console.log("> CONSOLE:", (msg.text() + ' - ' + msg.location().url).replace(/\s+/g, ' ')));
  page.on('pageerror', err => console.log("> PAGEERROR:", ('' + err).replace(/\s+/g, ' ')));

  const url = `http://${host}:${port}/`;
  await page.goto(url);
  await page.waitForURL(url);
  await page.waitForTimeout(3000);

  if (mode == 'prod') {
    log("Skipping creating views for production mode\n");
    const text = page.getByText('Could not navigate');
    assert.ok(await text.isVisible());
  } else {
    const linkText = /react/.test(name) ?
      'Create a view for coding the UI in TypeScript with Hilla and React' :
      'Create a view for coding the UI in Java with Flow';
    const viewName = /react/.test(name) ? '@index.tsx' : 'HomeView.java';

    log(`Creating ${viewName} view using copilot\n`);
    await page.getByRole('link', { name: linkText }).click();
    await page.waitForTimeout(2000);
    await page.reload();
    await page.waitForURL(url);
    const view = (await exec(`find src/main/frontend src/main/java -name '${viewName}'`)).stdout.trim();
    assert.ok(fs.existsSync(view));

    // Compile the application so as spring-devtools watches the changes
    await compile(page);

    // Wait for the frontend to be built
    const building = page.getByText('Building');
    if (await building.isVisible()) {
      log(`Waiting for frontend to be built ...`)
      while(await building.isVisible()) {
        process.stderr.write(".");
        await page.waitForTimeout(1000);
      }
      console.error('');
    }

    log(`checking if the new view is available\n`);
    try {
      // it could happen that port is not available yet
      await page.reload();
    } catch (error) {
      await page.waitForTimeout(2000);
      await page.reload();
    }
    await page.waitForURL(url);
    await page.waitForTimeout(2000);
    const text = page.getByText('Welcome');
    assert.ok(await text.isVisible());

    log(`Removing the view ${view}\n`);
    fs.unlinkSync(view);
  }

  await context.close();
  await browser.close();
})();
