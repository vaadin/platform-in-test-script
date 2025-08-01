#!/usr/bin/env node

import { parseArguments, validateConfig } from './cli/args.js';
import { PitRunner } from './core/pitRunner.js';
import { PlaywrightRunner } from './core/playwrightRunner.js';
import { logger } from './utils/logger.js';

async function main(): Promise<void> {
  try {
    // Parse command line arguments
    const config = parseArguments(process.argv);

    // Validate configuration
    const validation = validateConfig(config);
    if (!validation.valid) {
      for (const error of validation.errors) {
        logger.error(error);
      }
      process.exit(1);
    }

    // Handle special function execution
    if (config.runFunction) {
      logger.info(`Running function: ${config.runFunction}`);
      // This would require dynamic function loading
      logger.error('Function execution not yet implemented');
      process.exit(1);
    }

    // Handle Playwright-only mode
    if (config.runPw) {
      const playwrightRunner = new PlaywrightRunner();
      await playwrightRunner.runMultipleTests(config);
      // runMultipleTests handles its own exit status
      return;
    }

    // Create and run PIT
    const runner = new PitRunner(config);
    await runner.run();
    
    // If we reach here, all tests passed - runner.run() calls process.exit(1) on failure
    // No need to call process.exit(0) explicitly

  } catch (error) {
    logger.error(`Fatal error: ${error}`);
    process.exit(1);
  }
}

// Handle uncaught exceptions
process.on('uncaughtException', (error) => {
  logger.error(`Uncaught exception: ${error.message}`);
  process.exit(1);
});

process.on('unhandledRejection', (reason) => {
  logger.error(`Unhandled rejection: ${reason}`);
  process.exit(1);
});

// Run the main function
main().catch((error) => {
  logger.error(`Main function error: ${error}`);
  process.exit(1);
});
