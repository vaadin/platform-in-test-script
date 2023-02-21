const { chromium } = require('playwright');
const fs = require('fs');
const { spawn } = require('child_process');
const os = require('os');

const sleep = ms => new Promise(r => setTimeout(r, ms));
const compile = async () => await exec(`${/^win/.test(process.platform) ? 'mvn.cmd' : 'mvn'} compiler:compile`);

async function exec(order, ops) {
  return new Promise((resolve, reject) => {
    const cmd = order.split(/ +/)[0];
    const arg = order.split(/ +/).splice(1);
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

let headless = false, host = 'localhost', port = '8080', hub = false;
process.argv.forEach(a => {
  if (/^--headless/.test(a)) {
    headless = true;
  } else if (/^--ip=/.test(a)) {
    ip = a.split('=')[1];
  } else if (/^--port=/.test(a)) {
    port = a.split('=')[1];
  }
});



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

  await page.goto(`http://${host}:${port}/`);

  await page.locator('text=Click me').click({timeout:60000});
  await page.locator('text=Clicked');

  console.log("Changing Click by Foo in src/main/java/com/vaadin/starter/MainView.java")
  await exec('perl -pi -e s/Click/Foo/g src/main/java/com/vaadin/starter/MainView.java');
  console.log(`Compiling ... ${/^win/.test(process.platform)}`);
  await compile();
  await sleep(5000);

  await page.locator('text=Foo me').click({timeout:60000});
  await page.locator('text=Fooed');

  console.log("Changing back Foo by Click in src/main/java/com/vaadin/starter/MainView.java")
  await exec('git checkout src/main/java/com/vaadin/starter/MainView.java')
  console.log("Compiling ...")
  await compile();
  await sleep(5000);

  await page.locator('text=Click me').click({timeout:60000});
  await page.locator('text=Clicked');

  // ---------------------
  await context.close();
  await browser.close();
})();
