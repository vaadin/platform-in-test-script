import { exec } from 'child_process';
import { chromium, Page, Browser, Response } from 'playwright';
import { promisify } from 'util';
import * as path from 'path';

export interface TestArgs {
  headless: boolean;
  port: string;
  host: string;
  pass: string;
  ignoreHTTPSErrors: boolean;
  url?: string;
  login?: string;
  tmppass?: string;
  mode?: string;
  registry?: string;
  tag?: string;
  secret?: string;
  version?: string;
}

export interface PageWithBrowser extends Page {
  browser: Browser;
}

function computeTime(): string {
  if (!process.env['START']) return "";
  const timeElapsed = Math.floor(Date.now() / 1000) - parseInt(process.env['START']);
  const mins = Math.floor(timeElapsed / 60);
  const secs = timeElapsed % 60;
  const str = `${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
  return `\x1b[2;36m - ${str}\x1b[0m`;
}

export function log(...args: any[]): void {
  const str = `${args}`.replace(/\n$/, '');
  process.stderr.write(`\x1b[0m> \x1b[0;32m${str}\x1b[0m${computeTime()}\n`);
}

export function out(...args: any[]): void {
  process.stdout.write(`\x1b[2m\x1b[196m${args}\x1b[0m`);
}

export function ok(...args: any[]): void {
  process.stderr.write(`\x1b[2m\x1b[92m${args}\x1b[0m`);
}

export function warn(...args: any[]): void {
  process.stderr.write(`\x1b[2m\x1b[91m${args}\x1b[0m`);
}

let lastErr: string;
export function err(...args: any[]): void {
  process.stderr.write(`\x1b[0;31m${args}\x1b[0m`.split('\n')[0] + '\n');
  const str = `${args.toString().split('\n').slice(1).join('\n')}`;
  if (str !== lastErr) {
    out(str);
    lastErr = str;
  }
}

export const run = async (cmd: string): Promise<string> => {
  const result = await promisify(exec)(cmd);
  return result.stdout;
};

let mode: string, version: string;

export const args = (): TestArgs => {
  const ret: TestArgs = {
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
      ret.host = a.split('=')[1] || ret.host;
    } else if (/^--port=/.test(a)) {
      ret.port = a.split('=')[1] || ret.port;
    } else if (/^--url=/.test(a)) {
      const value = a.split('=')[1];
      if (value) ret.url = value;
    } else if (/^--login=/.test(a)) {
      const value = a.split('=')[1];
      if (value) ret.login = value;
    } else if (/^--pass=/.test(a)) {
      ret.pass = a.split('=')[1] || ret.pass;
    } else if (/^--tmppass=/.test(a)) {
      const value = a.split('=')[1];
      if (value) ret.tmppass = value;
    } else if (/^--notls/.test(a)) {
      ret.ignoreHTTPSErrors = true;
    } else if (/^--mode/.test(a)) {
      const value = a.split('=')[1];
      if (value) {
        mode = ret.mode = value;
      }
    } else if (/^--registry/.test(a)) {
      const value = a.split('=')[1];
      if (value) ret.registry = value;
    } else if (/^--tag/.test(a)) {
      const value = a.split('=')[1];
      if (value) ret.tag = value;
    } else if (/^--secret/.test(a)) {
      const value = a.split('=')[1];
      if (value) ret.secret = value;
    } else if (/^--version/.test(a)) {
      const value = a.split('=')[1];
      if (value) {
        version = ret.version = value;
      }
    }
  });
  
  if (!ret.url) {
    ret.url = `http://${ret.host}:${ret.port}/`;
  }
  
  return ret;
};

export async function createPage(headless: boolean, ignoreHTTPSErrors: boolean): Promise<PageWithBrowser> {
  let slowMo = 1000;
  if (process.env['FAST']) {
    slowMo = 0;
  } else if (headless) {
    slowMo = 400;
  }
  
  const browser = await chromium.launch({
    headless: headless,
    chromiumSandbox: false,
    slowMo: slowMo,
    args: ['--window-position=0,0']
  });
  
  const context = await browser.newContext({
    ignoreHTTPSErrors: ignoreHTTPSErrors,
    locale: 'en-US',
    viewport: { width: 1792, height: 970 }
  });
  
  const page = await context.newPage() as PageWithBrowser;
  page.browser = browser;
  
  page.on('console', msg => {
    const text = `${msg.text()} - ${msg.location().url}`.replace(/\s+/g, ' ');
    if (!/vaadinPush|favicon.ico|Autofocus/.test(text)) {
      out("> CONSOLE:", text, '\n');
    }
  });
  
  page.on('pageerror', e => warn("> JSERROR:", ('' + e).replace(/\s+/g, ' '), '\n'));
  
  return page;
}

export async function closePage(page: PageWithBrowser): Promise<void> {
  await page.context().close();
  await page.browser.close();
}

const screenshots = "screenshots.out";
let sscount = 0;

export async function takeScreenshot(page: Page, name: string, descr: string): Promise<void> {
  if (process.env['FAST']) return;
  
  const scr = path.basename(name);
  const cnt = String(++sscount).padStart(2, "0");
  const file = `${screenshots}/${mode ? mode + '-' : ''}${version ? version + '-' : ''}${scr}-${cnt}-${descr}.png`;
  
  let timeout = 200;
  if (process.platform.startsWith('win')) {
    timeout = 10000;
  } else if (process.env['GITHUB_ACTIONS']) {
    timeout = 800;
  }
  
  await page.waitForTimeout(timeout);
  await page.screenshot({ path: file });
  out(` 📸 Screenshot taken: ${file}\n`);
}

export interface ServerReadyOptions {
  maxRetries?: number;
  retryInterval?: number;
}

export async function waitForServerReady(page: Page, url: string, options: ServerReadyOptions = {}): Promise<Response> {
  const {
    maxRetries = 35,
    retryInterval = 5000
  } = options;

  log(`Opening ${url}\n`);
  
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    await page.goto('about:blank');
    try {
      const response = await page.goto(url, { timeout: 5000 });
      
      if (response && response.status() < 400) {
        await page.waitForTimeout(1000);
        ok(` ✓ Attempt ${attempt} Server is ready and returned a valid response. ${response.status()}\n`);
        return response;
      } else {
        out(` ⏲ Attempt ${attempt} Server is not ready yet. ${response?.status()}\n`);
      }
    } catch (error: any) {
      if (error.message.includes('net::ERR_CERT_AUTHORITY_INVALID')) {
        err(` ⏲ Attempt ${attempt} Server has not a valid certificate, install it for ${url} or use --notls flag\n`);
      } else {
        err(` ⏲ Attempt ${attempt} Server failed with error: ${error.message}\n`);
      }
    }
    await page.waitForTimeout(retryInterval);
  }
  
  throw new Error(`Server did not become ready after ${maxRetries} attempts.\n`);
}

export async function dismissDevmode(page: Page): Promise<boolean> {
  let dismiss = page.getByTestId('message').getByText('Dismiss');
  if (!await dismiss.count()) {
    dismiss = page.locator('copilot-notifications-container').getByLabel('Close');
  }
  if (await dismiss.count()) {
    await dismiss.click();
    return true;
  }
  return false;
}
