const { exec } = require('child_process');
const { spawn } = require('child_process');
const {chromium} = require('playwright');
const promisify = require('util').promisify;
const path = require('path');
const fs = require('fs');
const { defineConfig} = require('@playwright/test');
defineConfig({
  timeout: 60 * 1000,
  expect: {timeout: 30 * 1000},
});

function computeTime() {
  if (!process.env.START) return "";
  const timeElapsed =  Math.floor(Date.now() / 1000) - process.env.START;
  const mins = Math.floor(timeElapsed / 60);
  const secs = timeElapsed % 60;
  const str = `${String(mins).padStart(2, '0')}':${String(secs).padStart(2, '0')}"`
  return `\x1b[2;36m - ${str}\x1b[0m`
}

function log(...args) {
  const str = `${args}`.replace(/\n$/, '');
  process.stderr.write(`\x1b[0m> \x1b[0;32m${str}\x1b[0m${computeTime()}\n`);
}
function out(...args) {
  process.stdout.write(`\x1b[2m\x1b[196m${args}\x1b[0m`);
}
function ok(...args) {
  process.stderr.write(`\x1b[2m\x1b[92m${args}\x1b[0m`);
}
function warn(...args) {
  process.stderr.write(`\x1b[2m\x1b[91m${args}\x1b[0m`);
}
let lastErr;
function err(...args) {
  process.stderr.write(`\x1b[0;31m${args}\x1b[0m`.split('\n')[0] + '\n');
  const str = `${args.toString().split('\n').slice(1).join('\n')}`;
  if (str !== lastErr) {
    out(str);
    lastErr = str;
  }
}

const run = async (cmd) => (await promisify(exec)(cmd)).stdout;

async function execCommand(order, ops) {
  return new Promise((resolve, reject) => {
    const cmd = order.split(/ +/)[0];
    const arg = order.split(/ +/).splice(1);
    log(`Executing -> ${order}`);
    let stdout = "", stderr = "";
    const ls = spawn(cmd, arg, { shell: true });
    ls.stdout.on('data', (data) => stdout += data);
    ls.stderr.on('data', (data) => stderr += data);
    ls.on('close', (code) => {
      if (code !== 0) {
        log(`ERROR ${code} executing ${order}`);
        log(`STDOUT\n${stdout}`);
        log(`STDERR\n${stderr}`);
        reject({ stdout, stderr, code });
      } else {
        resolve({ stdout, stderr, code });
      }
    });
  });
}
let mode, version;

const args = () => {
  const ret = {
    headless: false,
    port: '8080',
    host: 'localhost',
    pass: 'Servantes',
    ignoreHTTPSErrors: false,
  };
  process.argv.forEach((a) => {
    if (/^--headless/.test(a)) {
      ret.headless = true;
    } else if (/^--host=/.test(a)) {
      ret.host = a.split('=')[1];
    } else if (/^--port=/.test(a)) {
      ret.port = a.split('=')[1];
    } else if (/^--url=/.test(a)) {
      ret.url = a.split('=')[1];
    } else if (/^--login=/.test(a)) {
      ret.login = a.split('=')[1];
    } else if (/^--pass=/.test(a)) {
      ret.pass = a.split('=')[1];
    } else if (/^--tmppass=/.test(a)) {
      ret.tmppass = a.split('=')[1];
    } else if (/^--notls/.test(a)) {
      ret.ignoreHTTPSErrors = true;
    } else if (/^--mode/.test(a)) {
      mode = ret.mode = a.split('=')[1];
    } else if (/^--registry/.test(a)) {
      ret.registry = a.split('=')[1];
    } else if (/^--tag/.test(a)) {
      ret.tag = a.split('=')[1];
    } else if (/^--secret/.test(a)) {
      ret.secret = a.split('=')[1];
    } else if (/^--version/.test(a)) {
      version = ret.version = a.split('=')[1];
    } else if (/^--prefix=/.test(a)) {
      ret.prefix = a.split('=')[1];
    } else if (/^--name=/.test(a)) {
      ret.name = a.split('=')[1];
    }
  });
  if (!ret.url) {
    ret.url = `http://${ret.host}:${ret.port}/`;
  }
  return ret;
};

async function createPage(headless, ignoreHTTPSErrors) {
    const browser = await chromium.launch({
        headless: headless,
        chromiumSandbox: false,
        slowMo: process.env.FAST ? 0 : headless ? 400: 1000,
        args: ['--window-position=0,0']
    });
    const context = await browser.newContext({ignoreHTTPSErrors: ignoreHTTPSErrors, locale: 'en-US', viewport: { width: 1792, height: 970 } });
    const page = await context.newPage();
    page.on('console', msg => {
      const text = `${msg.text()} - ${msg.location().url}`.replace(/\s+/g, ' ');
      if (!/vaadinPush|favicon.ico|Autofocus/.test(text))
        out("> CONSOLE:", text, '\n');
    });
    page.on('pageerror', e => warn("> JSERROR:", ('' + e).replace(/\s+/g, ' '), '\n'));
    page.browser = browser;
    return page;
}
async function closePage(page) {
    await takeScreenshot(page, getCallingTestFile(), 'ss', '_after');
    await page.goto('about:blank');
    await page.context().close();
    await page.browser.close();
}

const screenshots = "screenshots.out"
let sscount = 0;
async function takeScreenshot(page, name, descr, prefix) {
  if (process.env.FAST) return;
  const scr = path.basename(name);
  const cnt = String(++sscount).padStart(2, "0");
  const prefixStr = prefix ? prefix + '-' : '';
  const modeStr = mode ? mode + '-' : '';
  const file = `${screenshots}/${prefixStr}${modeStr}${version ? version + '-': '' }${scr}-${cnt}-${descr}.png`;
  await page.waitForTimeout(/^win/.test(process.platform) ? 10000 : process.env.GITHUB_ACTIONS ? 800 : 200);
  await page.screenshot({ path: file });
  out(` 📸 Screenshot taken: ${file}\n`);
}

// Helper function to get the calling test file name
function getCallingTestFile() {
  const stack = new Error().stack;
  const stackLines = stack.split('\n');

  // Look for the first line that contains a .js file that's not test-utils.js
  for (const line of stackLines) {
    if (line.includes('.js') && !line.includes('test-utils.js') && !line.includes('node_modules')) {
      const match = line.match(/\/([^\/]+\.js)/);
      if (match) {
        return match[1].replace('.js', '');
      }
    }
  }
  return '';
}

// Wait for the server to be ready and to get a valid response
async function waitForServerReady(page, url, options = {}) {
  const {
    selector,
    maxRetries = 35, // Max number of retries
    retryInterval = 5000 // Interval between retries in milliseconds
  } = options;
  log(`Opening ${url}\n`);
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    await page.goto('about:blank');
    try {
      const response = await page.goto(url, {timeout: 5000});
      // Check if the response status is not 503
      if (response && response.status() < 400) {
        if (options.selector) {
          await page.waitForSelector(selector, {timeout: 1000});
        } else {
          await page.waitForTimeout(1000);
        }
        ok(` ✓ Attempt ${attempt} Server is ready and returned a valid response. ${response.status()}\n`);
        await takeScreenshot(page, getCallingTestFile(), 'ss', '_before');
        return response;
      } else {
        out(` ⏲ Attempt ${attempt} Server is not ready yet. ${response.status()}\n`);
      }
    } catch (error) {
      if (error.message.includes('net::ERR_CERT_AUTHORITY_INVALID')) {
        err(` ⏲ Attempt ${attempt} Server has not a valid certificate, install it for ${url} or use --notls flag\n`);
      } else {
        err(` ⏲ Attempt ${attempt} Server failed with error: ${error.message}\n`);
      }
    }
    await page.waitForTimeout(retryInterval);
  }
  await takeScreenshot(page, getCallingTestFile(), 'ss', '_before');
  throw new Error(`Server did not become ready after ${maxRetries} attempts.\n`);
}

async function dismissDevmode(page) {
  let dismiss = page.getByTestId('message').getByText('Dismiss');
  if (!await dismiss.count()) {
    dismiss = page.locator('copilot-notifications-container').getByLabel('Close')
  }
  if (await dismiss.count()) {
    dismiss.click()
    return true;
  }
  return false;
}

// Unified compilation functions
function getBuildCommand() {
  const isWin = /^win/.test(process.platform);

  if (fs.existsSync('mvnw')) {
    const cmd = isWin ? (fs.existsSync('mvnw.bat') ? 'mvnw.bat' : 'mvnw.cmd') : './mvnw';
    return { cmd, args: 'compiler:compile' };
  } else if (fs.existsSync('gradlew')) {
    const cmd = isWin ? (fs.existsSync('gradlew.bat') ? 'gradlew.bat' : 'gradlew.cmd') : './gradlew';
    return { cmd, args: 'compileJava' };
  } else if (isWin) {
    return { cmd: 'mvn.cmd', args: 'compiler:compile' };
  } else {
    return { cmd: 'mvn', args: 'compiler:compile' };
  }
}

async function compileProject() {
  const { cmd, args } = getBuildCommand();
  return await execCommand(`${cmd} ${args}`);
}

async function compileAndReload(page, url, options = {}) {
  const { name, waitTime = 10000 } = options;

  log('Re-compiling project');
  await compileProject();
  log(`Sleeping ${waitTime / 1000}secs`);
  await page.waitForTimeout(waitTime);

  if (name && /jetty/.test(name)) {
    log('Reloading Page for Jetty');
    await page.reload();
    await page.waitForLoadState();
  } else if (url) {
    log('Reloading page');
    await page.reload();
    await page.waitForURL(url);
    log('Page reloaded');
  }
}

function setupCopilotConfig() {
  const os = require('os');
  const copilotConfigPath = path.join(os.homedir(), '.vaadin', 'copilot-configuration.json');
  const copilotConfig = {
    dismissedNotifications: ["devmode"],
    activationButtonPosition: { right: 212, bottom: 73 }
  };

  fs.mkdirSync(path.dirname(copilotConfigPath), { recursive: true });

  if (fs.existsSync(copilotConfigPath)) {
    const existingConfig = JSON.parse(fs.readFileSync(copilotConfigPath, 'utf8'));
    Object.assign(existingConfig, copilotConfig);
    fs.writeFileSync(copilotConfigPath, JSON.stringify(existingConfig, null, 2));
  } else {
    fs.writeFileSync(copilotConfigPath, JSON.stringify(copilotConfig, null, 2));
  }
}

module.exports = {
  log, out, err, warn,
  run,
  execCommand,
  args,
  createPage,
  closePage,
  takeScreenshot,
  waitForServerReady,
  dismissDevmode,
  compileAndReload,
  setupCopilotConfig,
};