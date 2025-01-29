const { exec } = require('child_process');
const {chromium} = require('playwright');
const promisify = require('util').promisify;
const path = require('path');
const { defineConfig} = require('@playwright/test');
defineConfig({
  timeout: 60 * 1000,
  expect: {timeout: 30 * 1000},
});

function log(...args) {
  process.stderr.write(`\x1b[0m> \x1b[0;32m${args}\x1b[0m`);
}
function out(...args) {
  process.stderr.write(`\x1b[2m\x1b[196m${args}\x1b[0m`);
}
function warn(...args) {
  process.stderr.write(`\x1b[2m\x1b[91m${args}\x1b[0m`);
}
function err(...args) {
  process.stderr.write(`\x1b[0;31m${args}\x1b[0m`);
}

const run = async (cmd) => (await promisify(exec)(cmd)).stdout;


const args = () => {
  const ret = {
    headless: false,
    port: '8000',
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
        slowMo: headless ? -1: 500,
        args: ['--window-position=0,0']
    });
    const context = await browser.newContext({ignoreHTTPSErrors: ignoreHTTPSErrors, viewport: { width: 1792, height: 970 } });
    const page = await context.newPage();
    page.on('console', msg => out("> CONSOLE:", (msg.text() + ' - ' + msg.location().url).replace(/\s+/g, ' '), '\n'));
    page.on('pageerror', e => warn("> JSERROR:", ('' + e).replace(/\s+/g, ' '), '\n'));
    page.browser = browser;
    return page;
}
async function closePage(page) {
    await page.context().close();
    await page.browser.close();
}

const screenshots = "screenshots.out"
let sscount = 0;
async function takeScreenshot(page, name, descr) {
  const scr = path.basename(name);
  const cnt = String(++sscount).padStart(2, "0");
  const file = `${screenshots}/${scr}-${cnt}-${descr}.png`;
  await page.waitForTimeout(1000);
  await page.screenshot({ path: file });
  out(` 📸 Screenshot taken: ${file}\n`);
}

// Wait for the server to be ready and to get a valid response
async function waitForServerReady(page, url, options = {}) {
  const {
    maxRetries = 20, // Max number of retries
    retryInterval = 5000 // Interval between retries in milliseconds
  } = options;

  log(`Opening ${url}\n`);
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      const response = await page.goto(url, {timeout: 120000});
      // Check if the response status is not 503
      if (response && response.status() < 400) {
        out(` ⏲ Attempt ${attempt} Server is ready and returned a valid response. ${response.status()}\n`);
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
      if (attempt >= 10) {
        throw new Error(`Server Error ${error}.\n`);
      }
    }
    await page.waitForTimeout(retryInterval);
  }
  throw new Error(`Server did not become ready after ${maxRetries} attempts.\n`);
}

module.exports = {
  log, out, err, warn,
  run,
  args,
  createPage,
  closePage,
  takeScreenshot,
  waitForServerReady,
};