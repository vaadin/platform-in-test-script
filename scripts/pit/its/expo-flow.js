const { expect } = require('@playwright/test');
const { log, args, createPage, closePage, takeScreenshot, waitForServerReady } = require('./test-utils');

(async () => {
    const arg = args();

    const page = await createPage(arg.headless);

    await waitForServerReady(page, arg.url, arg);

    await page.locator('html').first().innerHTML();
    await takeScreenshot(page, arg, __filename, 'page-loaded');

    await page.getByRole('link', { name: 'Chat' }).click();
    await takeScreenshot(page, arg, __filename, 'chat-loaded');
    await page.getByLabel('Message').fill('hello');
    await page.getByRole('button', { name: 'Send' }).click();
    await takeScreenshot(page, arg, __filename, 'chat-clicked');
    await expect(page.getByText('Assistant').first()).toBeVisible();
    await takeScreenshot(page, arg, __filename, 'chat-result');

    await page.getByRole('link', { name: 'Java Playground' }).click();
    await takeScreenshot(page, arg, __filename, 'java-loaded');
    await page.locator('vaadin-text-field input').fill('foo');
    await page.getByRole('button', { name: 'Say hello' }).click();
    await takeScreenshot(page, arg, __filename, 'java-clicked');
    await expect(page.getByRole('paragraph')).toContainText('Hello foo');

    await page.getByRole('link', { name: 'React Playground' }).click();
    await takeScreenshot(page, arg, __filename, 'react-loaded');
    await page.locator('vaadin-text-field input').fill('bar');
    await page.getByRole('button', { name: 'Say hello' }).click();
    if (process.env.RUNNER_OS != 'Windows') {
      await takeScreenshot(page, arg, __filename, 'react-clicked');
    }
    await expect(page.locator('vaadin-notification-container')).toContainText('Hello bar');
    await takeScreenshot(page, arg, __filename, 'react-result');

    await page.getByRole('link', { name: 'Order T-shirt' }).click();
    await takeScreenshot(page, arg, __filename, 'order-loaded');
    await page.getByLabel('Name').fill('Manolo');
    await page.getByLabel('Email').fill('mm@aa.es');
    await page.getByLabel('T-shirt size').click();
    await takeScreenshot(page, arg, __filename, 'size-clicked');
    await page.getByRole('option', { name: 'Small' }).locator('div').click();
    await page.getByRole('button', { name: 'Place order' }).click();
    if (process.env.RUNNER_OS != 'Windows') {
      await takeScreenshot(page, arg, __filename, 'order-clicked');
    }
    await expect(page.locator('vaadin-notification-container')).toContainText('Thank you');

    await closePage(page, arg);
})();




