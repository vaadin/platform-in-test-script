const { exec } = require('child_process');
const {chromium} = require('playwright');
const promisify = require('util').promisify;
const path = require('path');
const { defineConfig} = require('@playwright/test');
defineConfig({
  timeout: 60 * 1000,
  expect: {timeout: 30 * 1000},
});

const log = (s) => process.stderr.write(`   ${s}`);
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
        slowMo: 500
    });
    const context = await browser.newContext({ignoreHTTPSErrors: ignoreHTTPSErrors });
    const page = await context.newPage();
    page.on('console', msg => console.log("> CONSOLE:", (msg.text() + ' - ' + msg.location().url).replace(/\s+/g, ' ')));
    page.on('pageerror', err => console.log("> PAGEERROR:", ('' + err).replace(/\s+/g, ' ')));
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
  await page.waitForTimeout(10000);
  await page.screenshot({ path: file });
  log(`Screenshot taken: ${file}\n`);
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
      const response = await page.goto(url);
      // Check if the response status is not 503
      if (response && response.status() !== 503) {
        log(`Attempt ${attempt} Server is ready and returned a valid response. ${response.status()}\n`);
        return response;
      } else {
        log(`Attempt ${attempt} Server is not ready yet. ${response.status()}\n`);
      }
    } catch (error) {
      if (error.message.includes('net::ERR_CERT_AUTHORITY_INVALID')) {
        log(`Attempt ${attempt} Server has not a valid certificate, install it for ${url} or use --notls flag\n`);
      } else {
        log(`Attempt ${attempt} Server failed with error: ${error.message}\n`);
      }
    }
    await page.waitForTimeout(retryInterval);
  }
  throw new Error(`Server did not become ready after ${maxRetries} attempts.\n`);
}

module.exports = {
  log,
  run,
  args,
  createPage,
  closePage,
  takeScreenshot,
  waitForServerReady,
};