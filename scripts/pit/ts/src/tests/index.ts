export * from './baseTest.js';
export * from './start.test.js';
export * from './start-auth.test.js';
export * from './react.test.js';
export * from './react-starter.test.js';
export * from './basic.test.js';
export * from './click.test.js';
export * from './click-hotswap.test.js';
export * from './hello.test.js';
export * from './latest-java.test.js';
export * from './latest-javahtml.test.js';
export * from './noop.test.js';
export * from './spreadsheet-demo.test.js';
export * from './releases.test.js';
export * from './ai.test.js';
export * from './bookstore.test.js';
export * from './initializer.test.js';
export * from './collaboration.test.js';
export * from './oauth.test.js';
export * from './hybrid-react.test.js';
export * from './hybrid.test.js';
export * from './mpr-demo.test.js';
export * from './hilla-react-cli.test.js';
// export * from './cc-identity-management.test.js';  // Temporarily disabled due to compilation issues

import type { TestConfig } from './baseTest.js';
import { runStartTest } from './start.test.js';
import { runStartAuthTest } from './start-auth.test.js';
import { runReactTest } from './react.test.js';
import { runReactStarterTest } from './react-starter.test.js';
import { runBasicTest } from './basic.test.js';
import { runClickTest } from './click.test.js';
import { runClickHotswapTest } from './click-hotswap.test.js';
import { runHelloTest } from './hello.test.js';
import { runLatestJavaTest } from './latest-java.test.js';
import { runLatestJavaHtmlTest } from './latest-javahtml.test.js';
import { runNoopTest } from './noop.test.js';
import { runSpreadsheetDemoTest } from './spreadsheet-demo.test.js';
import { runReleasesTest } from './releases.test.js';
import { runAiTest } from './ai.test.js';
import { runBookstoreTest } from './bookstore.test.js';
import { runInitializerTest } from './initializer.test.js';
import { runCollaborationTest } from './collaboration.test.js';
import { runOauthTest } from './oauth.test.js';
import { runHybridReactTest } from './hybrid-react.test.js';
import { runHybridTest } from './hybrid.test.js';
import { runMprDemoTest } from './mpr-demo.test.js';
import { runHillaReactCliTest } from './hilla-react-cli.test.js';
import { logger } from '../utils/logger.js';

// Test runner interface
export type TestFunction = (config: TestConfig) => Promise<boolean>;

// Registry of all available tests with their file information
export const TEST_REGISTRY: Record<string, { testFunction: TestFunction; fileName: string }> = {
  // Core starter tests (from lib-start.sh getStartTestFile)
  'start': { testFunction: runStartTest, fileName: 'start.test.ts' },
  'start-auth': { testFunction: runStartAuthTest, fileName: 'start-auth.test.ts' },
  'basic': { testFunction: runBasicTest, fileName: 'basic.test.ts' },
  'click': { testFunction: runClickTest, fileName: 'click.test.ts' },
  'click-hotswap': { testFunction: runClickHotswapTest, fileName: 'click-hotswap.test.ts' },
  'hello': { testFunction: runHelloTest, fileName: 'hello.test.ts' },
  'noop': { testFunction: runNoopTest, fileName: 'noop.test.ts' },
  
  // React tests (from lib-start.sh)
  'react': { testFunction: runReactStarterTest, fileName: 'react-starter.test.ts' },  // 'react' starter uses react-starter.js
  'react-starter': { testFunction: runReactStarterTest, fileName: 'react-starter.test.ts' },
  'react-tutorial': { testFunction: runReactTest, fileName: 'react.test.ts' },  // 'react-tutorial' uses react.js
  
  // Latest Java tests
  'latest-java': { testFunction: runLatestJavaTest, fileName: 'latest-java.test.ts' },
  'latest-javahtml': { testFunction: runLatestJavaHtmlTest, fileName: 'latest-javahtml.test.ts' },
  
  // Demo tests (from lib-demos.sh getTest)
  'spreadsheet-demo': { testFunction: runSpreadsheetDemoTest, fileName: 'spreadsheet-demo.test.ts' },
  'releases': { testFunction: runReleasesTest, fileName: 'releases.test.ts' },
  'ai': { testFunction: runAiTest, fileName: 'ai.test.ts' },
  'bookstore': { testFunction: runBookstoreTest, fileName: 'bookstore.test.ts' },
  
  // Additional tests now migrated:
  'initializer': { testFunction: runInitializerTest, fileName: 'initializer.test.ts' },
  'collaboration': { testFunction: runCollaborationTest, fileName: 'collaboration.test.ts' },
  'oauth': { testFunction: runOauthTest, fileName: 'oauth.test.ts' },
  'hybrid-react': { testFunction: runHybridReactTest, fileName: 'hybrid-react.test.ts' },
  'hybrid': { testFunction: runHybridTest, fileName: 'hybrid.test.ts' },
  'mpr-demo': { testFunction: runMprDemoTest, fileName: 'mpr-demo.test.ts' },
  'hilla-react-cli': { testFunction: runHillaReactCliTest, fileName: 'hilla-react-cli.test.ts' },
  
  // Control Center tests (from lib-k8s-cc.sh CC_TESTS)
  // Note: cc-identity-management temporarily disabled due to compilation issues
  // 'cc-setup': { testFunction: runCcSetupTest, fileName: 'cc-setup.test.ts' },
  // 'cc-install-apps': { testFunction: runCcInstallAppsTest, fileName: 'cc-install-apps.test.ts' },
  // 'cc-localization': { testFunction: runCcLocalizationTest, fileName: 'cc-localization.test.ts' },
  
  // Additional tests that still need to be migrated:
  // 'k8s-demo': { testFunction: runK8sDemoTest, fileName: 'k8s-demo.test.ts' },
  // 'start-wizard': { testFunction: runStartWizardTest, fileName: 'start-wizard.test.ts' },
  // 'expo-flow': { testFunction: runExpoFlowTest, fileName: 'expo-flow.test.ts' },
  
  // Add more tests as they are converted
};

// Main test runner function
export async function runTest(testName: string, config: TestConfig): Promise<boolean> {
  const testEntry = TEST_REGISTRY[testName];
  
  if (!testEntry) {
    logger.error(`Test '${testName}' not found. Available tests: ${Object.keys(TEST_REGISTRY).join(', ')}`);
    return false;
  }

  const { testFunction, fileName } = testEntry;

  logger.info(`Initializing Playwright test: ${testName}`);
  logger.info(`Test File: ${fileName}`);
  logger.debug(`Test Parameters:`);
  logger.debug(`  ├─ Test Name: ${testName}`);
  logger.debug(`  ├─ Test File: ${fileName}`);
  logger.debug(`  ├─ Target URL: http://${config.host}:${config.port}`);
  logger.debug(`  ├─ Browser Mode: ${config.headless ? 'Headless' : 'Headed'}`);
  logger.debug(`  └─ Timeout: ${config.timeout} secs`);
  
  try {
    logger.info(`Starting test execution from ${fileName}...`);
    const result = await testFunction(config);
    if (result) {
      logger.success(`✓ Test '${testName}' (${fileName}) passed`);
    } else {
      logger.error(`✗ Test '${testName}' (${fileName}) failed`);
    }
    return result;
  } catch (error) {
    logger.error(`✗ Test '${testName}' (${fileName}) failed with error: ${error}`);
    return false;
  }
}

// Helper function to get test name from starter name (based on lib-start.sh and lib-demos.sh)
export function getTestForStarter(starterName: string): string | undefined {
  // Map starter names to test files exactly as in lib-start.sh getStartTestFile
  if (starterName.includes('-auth')) return 'start-auth';
  if (starterName === 'flow-crm-tutorial') return undefined;
  if (starterName === 'react-tutorial') return 'react-tutorial';  // Uses react.js
  if (starterName.startsWith('default') || starterName === 'vaadin-quarkus' || starterName.includes('_prerelease')) return 'hello';
  if (starterName.startsWith('initializer')) return 'initializer';
  if (starterName.startsWith('archetype')) return 'click-hotswap';
  if (starterName === 'hilla-react-cli') return 'hilla-react-cli';
  if (starterName === 'react') return 'react-starter';  // Uses react-starter.js
  if (starterName.startsWith('test-hybrid-react')) return 'hybrid-react';
  if (starterName.startsWith('test-hybrid')) return 'hybrid';
  if (starterName === 'flow-hilla-hybrid-example') return 'hybrid';
  if (starterName === 'react-crm-tutorial') return 'noop';
  if (starterName === 'collaboration') return 'collaboration';
  if (starterName === 'latest-java') return 'latest-java';
  
  // Demo mappings from lib-demos.sh getTest
  if (starterName.startsWith('skeleton')) return 'hello';
  if (starterName === 'mpr-demo') return 'mpr-demo';
  if (starterName === 'spreadsheet-demo') return 'spreadsheet-demo';
  if (starterName === 'k8s-demo-app') return 'k8s-demo';
  if (starterName === 'releases-graph') return 'releases';
  if (starterName === 'start' && starterName.includes('demo')) return 'start-wizard';  // demo context
  if (starterName === 'vaadin-oauth-example') return 'oauth';
  if (starterName === 'bookstore-example') return 'bookstore';
  if (starterName === 'form-filler-demo') return 'ai';
  if (starterName === 'expo-flow') return 'expo-flow';
  
  // Demos that use noop.js
  const noopDemos = [
    'cookbook', 'walking-skeleton', 'business-app-starter-flow', 'spring-petclinic-vaadin-flow',
    'gs-crud-with-vaadin', 'vaadin-form-example', 'vaadin-rest-example', 'vaadin-localization-example',
    'vaadin-database-example', 'layout-examples', 'flow-quickstart-tutorial', 'flow-spring-examples',
    'flow-crm-tutorial', 'vaadin-oauth-example', 'designer-tutorial', 'addon-starter-flow', 'testbench-demo'
  ];
  
  for (const demo of noopDemos) {
    if (starterName.includes(demo) || starterName.includes('hilla') || starterName.includes('addon-template')) {
      return 'noop';
    }
  }
  
  // Default test file
  return 'start';
}
