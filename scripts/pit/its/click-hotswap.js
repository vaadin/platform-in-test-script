const { chromium } = require('playwright');
const fs = require('fs');
const { spawn } = require('child_process');
const os = require('os');

const sleep = ms => new Promise(r => setTimeout(r, ms));
const compileMvn = async () => await exec(`${/^win/.test(process.platform) ? 'mvn.cmd' : 'mvn'} compiler:compile`);
async function compile(page) {
  await compileMvn();
  await sleep(6000);
  if (/jetty/.test(name)) {
    console.log('reloading');
    await page.reload();
    await page.waitForLoadState();
  }
}

async function exec(order, ops) {
  return new Promise((resolve, reject) => {
    const cmd = order.split(/ +/)[0];
    const arg = order.split(/ +/).splice(1);
    console.log(order);
    let stdout = "", stderr = "";
    const ls = spawn(cmd, arg);
    ls.stdout.on('data', (data) => stdout += data);
    ls.stderr.on('data', (data) => stderr += data);
    ls.on('close', (code) => {
      if (code !== 0) {
        reject({ stdout, stderr, code });
      } else {
        resolve({ stdout, stderr, code });
      }
    });
  });
}

let headless = false, host = 'localhost', port = '8080', hub = false, name;
process.argv.forEach(a => {
  if (/^--headless/.test(a)) {
    headless = true;
  } else if (/^--ip=/.test(a)) {
    ip = a.split('=')[1];
  } else if (/^--port=/.test(a)) {
    port = a.split('=')[1];
  } else if (/^--name=/.test(a)) {
    name = a.split('=')[1];
  }
});

const url = `http://${host}:${port}/`;

(async () => {
  const browser = await chromium.launch({
    headless: headless,
    chromiumSandbox: false
  });
  const context = await browser.newContext();

  // Open new page
  const page = await context.newPage();
  page.on('console', msg => console.log("> CONSOLE:", msg.text()));
  page.on('pageerror', err => console.log("> JSERROR:", err));

  await page.goto(url);
  await page.waitForURL(url);

  await page.locator('text=Click me').click({timeout:60000});
  await page.locator('text=Clicked');

  const java = (await exec('find src -name MainView.java')).stdout.trim();

  await exec(`perl -pi -e s/Click/Foo/g ${java}`);
  await compile(page);

  await page.locator('text=Foo me').click({timeout:60000});
  await page.locator('text=Fooed');

  await exec(`git checkout ${java}`)
  await compile(page);

  await page.locator('text=Click me').click({timeout:60000});
  await page.locator('text=Clicked');

  // ---------------------
  await context.close();
  await browser.close();
})();
