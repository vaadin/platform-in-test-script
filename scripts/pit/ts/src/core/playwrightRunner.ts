import { logger } from '../utils/logger.js';
import { runTest, getTestForStarter, type TestConfig } from '../tests/index.js';
import type { PitConfig } from '../types.js';
import { PLAYWRIGHT_TIMEOUTS } from '../constants.js';

export interface PlaywrightTestOptions {
  port: number;
  mode: 'dev' | 'prod';
  name: string;
  version: string;
  headless: boolean;
}

export class PlaywrightRunner {

  // Single test runner (used by ValidationRunner)
  async runTests(testFile: string | undefined, options: PlaywrightTestOptions): Promise<void> {
    // If no test file specified, use the mapping function to get the correct test name
    let testName: string | undefined = testFile;
    
    if (!testName) {
      // Use the mapping function to convert starter name to test name
      testName = getTestForStarter(options.name);
    }
    
    // Remove .js extension if present (convert from old naming)
    if (testName?.endsWith('.js')) {
      testName = testName.slice(0, -3);
    }

    if (!testName) {
      logger.info(`No test found for starter: ${options.name}`);
      return;
    }

    logger.info(`Running Playwright test: ${testName} for ${options.name}`);

    // Create test configuration
    const testConfig: TestConfig = {
      url: `http://localhost:${options.port}`,
      starter: options.name,
      mode: options.mode,
      version: options.version,
      headless: options.headless,
      host: 'localhost',
      port: options.port,
      timeout: options.mode === 'dev' ? PLAYWRIGHT_TIMEOUTS.TIMEOUT_DEV_MS : PLAYWRIGHT_TIMEOUTS.TIMEOUT_PROD_MS
    };

    // Run the TypeScript test
    const success = await runTest(testName, testConfig);

    if (!success) {
      throw new Error(`Playwright test '${testName}' failed for ${options.name}`);
    }

    logger.success(`✓ Playwright test '${testName}' passed for ${options.name}`);
  }

  // Multiple test runner (used for --run-pw functionality)
  async runMultipleTests(config: PitConfig): Promise<void> {
    logger.setOptions(config.verbose, config.debug);
    logger.separator('Running Playwright Tests Only');

    // Parse starters
    const starters = config.starters.split(',').map(s => s.trim()).filter(Boolean);

    if (starters.length === 0) {
      logger.error('No starters specified. Use --starters to specify which tests to run.');
      process.exit(1);
    }

    logger.info(`Running Playwright tests for: ${starters.join(', ')}`);
    logger.info(`Assuming server is running on http://localhost:${config.port}`);

    const results: Array<{ starter: string; success: boolean; error?: string }> = [];

    for (const starter of starters) {
      logger.separator(`Running Playwright Test: ${starter}`);
      
      const testConfig: TestConfig = {
        url: `http://localhost:${config.port}`,
        host: 'localhost',
        port: config.port,
        headless: config.headless || !config.headed,
        timeout: config.timeout * 1000, // Convert to milliseconds
      };

      // Log test execution details
      logger.info(`Test Configuration:`);
      logger.info(`  ├─ Starter: ${starter}`);
      logger.info(`  ├─ Host: ${testConfig.host}`);
      logger.info(`  ├─ Port: ${testConfig.port}`);
      logger.info(`  ├─ Headless: ${testConfig.headless}`);
      logger.info(`  ├─ Timeout: ${testConfig.timeout}ms (${config.timeout}s)`);
      logger.info(`  └─ URL: http://${testConfig.host}:${testConfig.port}`);
      
      try {
        logger.info(`Executing Playwright test for '${starter}'...`);
        
        // Get the correct test name for this starter (same logic as single test runner)
        let testName = getTestForStarter(starter);
        
        if (!testName) {
          logger.error(`No test found for starter: ${starter}`);
          results.push({ starter, success: false, error: `No test found for starter: ${starter}` });
          continue;
        }
        
        // Remove .js extension if present (convert from old naming)
        if (testName.endsWith('.js')) {
          testName = testName.slice(0, -3);
        }
        
        const success = await runTest(testName, testConfig);

        results.push({ starter, success });
        
        if (success) {
          logger.success(`✓ Test '${starter}' passed`);
        } else {
          logger.error(`✗ Test '${starter}' failed`);
        }
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        logger.error(`✗ Test '${starter}' failed: ${errorMessage}`);
        results.push({ starter, success: false, error: errorMessage });
      }
    }

    // Report final results
    this.reportResults(results);
  }

  private reportResults(results: Array<{ starter: string; success: boolean; error?: string }>): void {
    logger.separator('Playwright Test Results');

    const successful = results.filter(r => r.success);
    const failed = results.filter(r => !r.success);

    if (successful.length > 0) {
      logger.info('Successful tests:');
      successful.forEach(r => logger.info(`  ✓ ${r.starter}`));
    }

    if (failed.length > 0) {
      logger.info('\nFailed tests:');
      failed.forEach(r => {
        const errorSuffix = r.error ? ` - ${r.error}` : '';
        logger.error(`  ✗ ${r.starter}${errorSuffix}`);
      });
    }

    logger.info(`\nTotal: ${results.length}, Passed: ${successful.length}, Failed: ${failed.length}`);

    if (failed.length > 0) {
      process.exit(1);
    }
  }
}
