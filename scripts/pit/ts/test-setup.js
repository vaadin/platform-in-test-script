#!/usr/bin/env node

/**
 * Simple test to verify the TypeScript PiT setup works
 */

import { parseArguments } from './src/cli/args.js';
import { logger } from './src/utils/logger.js';

// Test basic functionality
logger.info('Testing PiT TypeScript setup...');

// Test argument parsing
try {
  const testArgs = ['node', 'test.js', '--test', '--verbose', '--starters=latest-java'];
  const config = parseArguments(testArgs);
  
  logger.info('✓ Argument parsing works');
  logger.info(`  Test mode: ${config.test}`);
  logger.info(`  Verbose: ${config.verbose}`);
  logger.info(`  Starters: ${config.starters}`);
  
  logger.success('PiT TypeScript setup is working correctly!');
  
} catch (error) {
  logger.error(`Setup test failed: ${error}`);
  process.exit(1);
}
