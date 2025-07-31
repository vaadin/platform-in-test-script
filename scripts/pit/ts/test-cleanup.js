import { CollaborationTest } from './dist/tests/collaboration.test.js';
import { logger } from './dist/utils/logger.js';

async function testBrowserCleanup() {
  logger.info('Testing browser cleanup for collaboration test...');
  
  const config = {
    url: 'http://localhost:8080',
    headless: true,
    host: 'localhost',
    port: 8080,
    timeout: 10000
  };

  const test = new CollaborationTest(config);
  
  try {
    // This should setup browsers and then clean them up
    logger.info('Setting up browsers...');
    await test.setup();
    
    // Simulate doing something with the browsers
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    logger.info('Starting teardown...');
    await test.teardown();
    
    logger.success('Browser cleanup test completed successfully');
  } catch (error) {
    logger.error(`Browser cleanup test failed: ${error}`);
  }
}

testBrowserCleanup().catch(console.error);
