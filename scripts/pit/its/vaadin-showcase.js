const { log, args, createPage, closePage, takeScreenshot, waitForServerReady, dismissDevmode } = require('./test-utils');

(async () => {
    const arg = args();
    const page = await createPage(arg.headless);

    await waitForServerReady(page, arg.url, arg);
    await takeScreenshot(page, arg, __filename, 'login-page');

    // --- Login ---
    log('Logging in');
    await page.locator('input[name="username"]').fill('admin');
    await page.locator('input[name="password"]').fill('admin');
    await page.locator('vaadin-button[role="button"]:has-text("Log in")').click();
    await page.waitForLoadState();
    await dismissDevmode(page);
    await takeScreenshot(page, arg, __filename, 'logged-in');

    // --- Hello World ---
    log('Testing Hello World');
    await page.goto(`${arg.url}hello-world`);
    await page.waitForLoadState();
    await page.getByLabel('Your name').fill('Test User');
    await page.getByRole('button', { name: 'Say hello' }).click();
    await page.locator('text=Hello Test User').waitFor({ state: 'visible' });
    await takeScreenshot(page, arg, __filename, 'hello-world');

    // --- Dashboard ---
    log('Testing Dashboard');
    await page.goto(`${arg.url}dashboard`);
    await page.waitForLoadState();
    await page.locator('text=Current users').waitFor({ state: 'visible' });
    await page.locator('text=View events').first().waitFor({ state: 'visible' });
    await page.locator('text=Conversion rate').waitFor({ state: 'visible' });
    // Verify chart has data series
    await page.locator('text=Berlin').waitFor({ state: 'visible' });
    await page.locator('text=London').waitFor({ state: 'visible' });
    // Verify service health grid has data
    await page.locator('text=Service health').waitFor({ state: 'visible' });
    await page.locator('text=Response times').waitFor({ state: 'visible' });
    await takeScreenshot(page, arg, __filename, 'dashboard');

    // --- Feed ---
    log('Testing Feed');
    await page.goto(`${arg.url}feed`);
    await page.waitForLoadState();
    // Feed should show cards with user content
    const feedCards = page.locator('vaadin-horizontal-layout').first();
    await feedCards.waitFor({ state: 'visible' });
    await takeScreenshot(page, arg, __filename, 'feed');

    // --- Data Grid ---
    log('Testing Data Grid');
    await page.goto(`${arg.url}data-grid`);
    await page.waitForLoadState();
    // Wait for grid to load with data
    await page.locator('vaadin-grid-pro').waitFor({ state: 'visible' });
    // Verify grid has rows
    const gridRows = page.locator('vaadin-grid-pro vaadin-grid-cell-content');
    await gridRows.first().waitFor({ state: 'visible' });
    await takeScreenshot(page, arg, __filename, 'data-grid');

    // --- Master-Detail ---
    log('Testing Master-Detail');
    await page.goto(`${arg.url}master-detail`);
    await page.waitForLoadState();
    await page.locator('vaadin-grid').first().waitFor({ state: 'visible' });
    // Click on a row to open detail
    const firstRow = page.locator('vaadin-grid-cell-content').first();
    await firstRow.waitFor({ state: 'visible' });
    await firstRow.click();
    // Verify the form appears with fields
    await page.getByRole('textbox', { name: 'First Name' }).waitFor({ state: 'visible' });
    await page.getByRole('textbox', { name: 'Last Name' }).waitFor({ state: 'visible' });
    await takeScreenshot(page, arg, __filename, 'master-detail');

    // --- Person Form ---
    log('Testing Person Form');
    await page.goto(`${arg.url}person-form`);
    await page.waitForLoadState();
    await page.getByLabel('First Name').waitFor({ state: 'visible' });
    await page.getByLabel('First Name').fill('John');
    await page.getByLabel('Last Name').fill('Doe');
    await takeScreenshot(page, arg, __filename, 'person-form');

    // --- Address Form ---
    log('Testing Address Form');
    await page.goto(`${arg.url}address-form`);
    await page.waitForLoadState();
    await page.getByLabel('Street Address').waitFor({ state: 'visible' });
    await page.getByLabel('Street Address').fill('123 Main St');
    await page.getByLabel('Postal Code').fill('12345');
    await page.getByLabel('City').fill('Springfield');
    await takeScreenshot(page, arg, __filename, 'address-form');

    // --- Credit Card Form ---
    log('Testing Credit Card Form');
    await page.goto(`${arg.url}credit-card-form`);
    await page.waitForLoadState();
    await page.getByLabel('Credit card number').waitFor({ state: 'visible' });
    await page.getByLabel('Credit card number').fill('4111111111111111');
    await page.getByLabel('Cardholder name').fill('JOHN DOE');
    await takeScreenshot(page, arg, __filename, 'credit-card-form');

    // --- Checkout Form ---
    log('Testing Checkout Form');
    await page.goto(`${arg.url}checkout-form`);
    await page.waitForLoadState();
    // Verify multi-section layout
    await page.getByRole('heading', { name: 'Personal details' }).first().waitFor({ state: 'visible' });
    await page.getByRole('heading', { name: 'Shipping Address' }).first().waitFor({ state: 'visible' });
    await takeScreenshot(page, arg, __filename, 'checkout-form');

    // --- Grid with Filters ---
    log('Testing Grid with Filters');
    await page.goto(`${arg.url}grid-with-filters`);
    await page.waitForLoadState();
    await page.locator('vaadin-grid').first().waitFor({ state: 'visible' });
    // Try filtering by name
    const nameFilter = page.getByRole('textbox', { name: 'Name' });
    await nameFilter.waitFor({ state: 'visible' });
    await nameFilter.fill('A');
    await page.waitForTimeout(1000);
    await takeScreenshot(page, arg, __filename, 'grid-with-filters');

    // --- Map ---
    log('Testing Map');
    await page.goto(`${arg.url}map`);
    await page.waitForLoadState();
    await page.locator('vaadin-map').waitFor({ state: 'visible', timeout: 10000 });
    await takeScreenshot(page, arg, __filename, 'map');

    // --- Image Gallery ---
    log('Testing Image Gallery');
    await page.goto(`${arg.url}image-gallery`);
    await page.waitForLoadState();
    // Wait for images to appear
    await page.locator('img').first().waitFor({ state: 'visible' });
    await takeScreenshot(page, arg, __filename, 'image-gallery');

    // --- Spreadsheet ---
    log('Testing Spreadsheet');
    await page.goto(`${arg.url}spreadsheet`);
    await page.waitForLoadState();
    await page.locator('vaadin-spreadsheet').waitFor({ state: 'visible', timeout: 15000 });
    await takeScreenshot(page, arg, __filename, 'spreadsheet');

    // --- Page Editor ---
    log('Testing Page Editor');
    await page.goto(`${arg.url}page-editor`);
    await page.waitForLoadState();
    await page.locator('vaadin-rich-text-editor').waitFor({ state: 'visible' });
    await takeScreenshot(page, arg, __filename, 'page-editor');

    // --- Checkout Wizard ---
    log('Testing Checkout Wizard');
    await page.goto(`${arg.url}wizard/1`);
    await page.waitForLoadState();
    // Step 1 - Personal details form
    await page.getByRole('textbox', { name: 'Name' }).waitFor({ state: 'visible' });
    await page.getByRole('textbox', { name: 'Name' }).fill('John Doe');
    await page.getByRole('textbox', { name: 'Email address' }).fill('john@example.com');
    await page.getByRole('textbox', { name: 'Phone number' }).fill('+1234567890');
    await takeScreenshot(page, arg, __filename, 'wizard-step1');
    // Navigate to step 2
    await page.getByRole('link', { name: 'Next' }).click();
    await page.waitForLoadState();
    await page.waitForTimeout(1000);
    await takeScreenshot(page, arg, __filename, 'wizard-step2');

    // --- CRUD Component ---
    log('Testing CRUD Component');
    await page.goto(`${arg.url}crud`);
    await page.waitForLoadState();
    await page.locator('vaadin-crud').waitFor({ state: 'visible' });
    await takeScreenshot(page, arg, __filename, 'crud');

    // --- Addons ---
    log('Testing Addons');
    await page.goto(`${arg.url}addons`);
    await page.waitForLoadState();
    await page.waitForTimeout(2000);
    await takeScreenshot(page, arg, __filename, 'addons');

    // --- Grid with Filters REST ---
    log('Testing Grid with Filters REST');
    await page.goto(`${arg.url}grid-with-filters-rest`);
    await page.waitForLoadState();
    await page.locator('vaadin-grid').first().waitFor({ state: 'visible' });
    await page.locator('vaadin-grid-cell-content').first().waitFor({ state: 'visible' });
    await takeScreenshot(page, arg, __filename, 'grid-filters-rest');

    // --- Editable Grid Button ---
    log('Testing Editable Grid Button');
    await page.goto(`${arg.url}grid-edit`);
    await page.waitForLoadState();
    await page.locator('vaadin-grid').first().waitFor({ state: 'visible' });
    // Verify grid loaded with data rows
    await page.locator('vaadin-grid-cell-content').first().waitFor({ state: 'visible' });
    await takeScreenshot(page, arg, __filename, 'grid-edit-button');

    // --- Master-Detail Responsive ---
    log('Testing Master-Detail Responsive');
    await page.goto(`${arg.url}master-detail-responsive`);
    await page.waitForLoadState();
    await page.locator('vaadin-grid').first().waitFor({ state: 'visible' });
    await takeScreenshot(page, arg, __filename, 'master-detail-responsive');

    log('All vaadin-showcase tests passed');
    await closePage(page, arg);
})();
