import type { PitConfig, TestResult } from '../types.js';
import { logger } from '../utils/logger.js';
import { checkCommands } from '../utils/system.js';
import { ensureDirectory, removeDirectory, joinPaths } from '../utils/file.js';
import { PRESETS, DEMOS } from '../constants.js';
import { StarterRunner } from './starterRunner.js';
import { DemoRunner } from './demoRunner.js';

export class PitRunner {
  private readonly config: PitConfig;
  private readonly startTime: number;
  private readonly successfulTests: string[] = [];
  private readonly failedTests: string[] = [];
  private readonly starterRunner: StarterRunner;
  private readonly demoRunner: DemoRunner;

  constructor(config: PitConfig) {
    this.config = config;
    this.startTime = Date.now();
    this.starterRunner = new StarterRunner(config);
    this.demoRunner = new DemoRunner(config);

    // Set logger options (verbose shows 🐛 debug messages, debug shows command output)
    logger.setOptions(config.verbose, config.debug);

    // Set up cleanup handlers
    this.setupCleanupHandlers();
  }

  private setupCleanupHandlers(): void {
    const cleanup = async (signal: string) => {
      logger.info(`Received ${signal}, shutting down gracefully...`);
      logger.info('Cleaning up managed processes...');
      
      // Close stdin to avoid hanging
      if (process.stdin.readable) {
        process.stdin.pause();
        process.stdin.destroy();
      }
      
      const { processManager } = await import('../utils/processManager.js');
      await processManager.killAllProcesses();
      
      // Exit with appropriate status based on test results
      const exitCode = this.failedTests.length > 0 ? 1 : 0;
      process.exit(exitCode);
    };

    process.on('SIGINT', () => cleanup('SIGINT'));
    process.on('SIGTERM', () => cleanup('SIGTERM'));
  }

  async run(): Promise<void> {
    logger.separator(this.config.test ? 'Showing PiT Commands' : 'Executing PiT Tests');

    // Check required commands
    const requiredCommands = ['git', 'mvn', 'curl', 'jq'];
    if (!(await checkCommands(requiredCommands))) {
      throw new Error('Missing required commands');
    }

    // Create temporary directory
    const tempDir = joinPaths(process.cwd(), 'tmp');
    await ensureDirectory(tempDir);

    try {
      // Compute which starters to run
      const starters = this.computeStarters();
      
      // Separate presets and demos
      const { presets, demos } = this.categorizeStarters(starters);

      // Clean Maven cache if not skipped
      if (!this.config.skipClean) {
        await this.cleanMavenCache();
      }

      // Run presets (start.vaadin.com or archetypes)
      logger.info(`📋 Processing ${presets.length} presets and ${demos.length} demos...`);
      
      for (let i = 0; i < presets.length; i++) {
        const preset = presets[i];
        if (preset) {
          const memUsed = Math.round(process.memoryUsage().heapUsed / 1024 / 1024);
          logger.info(`📦 [${i + 1}/${presets.length}] Processing preset: ${preset} (Memory: ${memUsed}MB)`);
          await this.runSingleTest('preset', preset, tempDir);
        }
      }

      // Run demos (GitHub repositories)
      for (let i = 0; i < demos.length; i++) {
        const demo = demos[i];
        if (demo) {
          const memUsed = Math.round(process.memoryUsage().heapUsed / 1024 / 1024);
          logger.info(`🚀 [${i + 1}/${demos.length}] Processing demo: ${demo} (Memory: ${memUsed}MB)`);
          await this.runSingleTest('demo', demo, tempDir);
        }
      }

      // Report results
      this.reportResults();

    } finally {
      // Cleanup
      await this.cleanup(tempDir);
      
      // Ensure all managed processes are killed using the new process manager
      const { processManager } = await import('../utils/processManager.js');
      await processManager.killAllProcesses();
      
      // Ensure stdin is properly closed to prevent hanging
      if (process.stdin.readable) {
        process.stdin.pause();
        process.stdin.destroy();
      }
    }
  }

  private computeStarters(): string[] {
    let starters = this.config.starters;

    // Handle exclusions (starters beginning with !)
    const exclusions: string[] = [];
    const included: string[] = [];

    for (const starter of starters.split(',')) {
      const trimmed = starter.trim();
      if (trimmed.startsWith('!')) {
        exclusions.push(trimmed.substring(1));
      } else if (trimmed) {
        included.push(trimmed);
      }
    }

    // Apply exclusions
    let finalStarters = included.length > 0 ? included : [...PRESETS, ...DEMOS];
    
    for (const exclusion of exclusions) {
      finalStarters = finalStarters.filter(s => !s.includes(exclusion));
    }

    return finalStarters;
  }

  private categorizeStarters(starters: string[]): { presets: string[]; demos: string[] } {
    const presets: string[] = [];
    const demos: string[] = [];

    for (const starter of starters) {
      const baseName = starter.split(':')[0]; // Handle variants
      
      if (PRESETS.some(p => p === baseName)) {
        presets.push(starter);
      } else if (DEMOS.some(d => d === baseName || d.includes(baseName || ''))) {
        demos.push(starter);
      }
    }

    return { presets, demos };
  }

  private async runSingleTest(
    type: 'preset' | 'demo',
    starterName: string,
    tempDir: string
  ): Promise<void> {
    logger.separator(`${this.config.test ? 'Showing Commands' : 'Testing'} '${starterName}'`);

    try {
      let result: TestResult;

      if (type === 'preset') {
        result = await this.starterRunner.run(starterName, tempDir);
      } else {
        result = await this.demoRunner.run(starterName, tempDir);
      }

      if (result.success) {
        logger.success(`'${starterName}' was built and tested successfully`);
        this.successfulTests.push(starterName);
      } else {
        logger.error(`Error testing '${starterName}': ${result.error || 'Unknown error'}`);
        this.failedTests.push(starterName);
      }

    } catch (error) {
      logger.error(`Error testing '${starterName}': ${error}`);
      this.failedTests.push(starterName);
    } finally {
      await this.killProcesses();
      await this.cleanupTest(tempDir, starterName);
    }
  }

  private async cleanMavenCache(): Promise<void> {
    if (this.config.test) {
      logger.info('Would clean Maven cache');
      return;
    }

    logger.info('Cleaning Maven cache...');
    // Implementation would go here
  }

  private async killProcesses(): Promise<void> {
    if (this.config.test) {
      logger.info('Would kill running processes');
      return;
    }

    // Kill any running test processes using the new process manager
    const { processManager } = await import('../utils/processManager.js');
    await processManager.killAllProcesses();
  }

  private async cleanupTest(_tempDir: string, starterName: string): Promise<void> {
    if (this.config.test) {
      logger.info(`Would cleanup test files for ${starterName}`);
      return;
    }

    // Kill any remaining processes for this test
    const { killProcessesByPort } = await import('../utils/system.js');
    await killProcessesByPort(this.config.port);
  }

  private async cleanup(tempDir: string): Promise<void> {
    if (this.config.test) {
      logger.info('Would cleanup temporary files');
      return;
    }

    try {
      await removeDirectory(tempDir);
      logger.debug('Temporary directory cleaned up');
    } catch (error) {
      logger.warn(`Failed to cleanup temporary directory: ${error}`);
    }
  }

  private reportResults(): void {
    if (this.config.test) {
      return;
    }

    logger.separator('Test Results');

    // Report successful tests
    for (const test of this.successfulTests) {
      logger.success(`🟢 Starter ${test} built successfully`);
    }

    // Report failed tests
    let hasErrors = false;
    for (const test of this.failedTests) {
      logger.error(`🔴 ERROR in ${test}`);
      hasErrors = true;
    }

    // Print execution time
    logger.printTime(this.startTime);

    if (hasErrors) {
      process.exit(1);
    }
  }
}
