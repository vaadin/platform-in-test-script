import { ChildProcess, spawn } from 'child_process';
import { logger } from './logger.js';

export interface ManagedProcess {
  id: string;
  command: string;
  process: ChildProcess;
  startTime: Date;
  outputFile?: string | undefined;
}

/**
 * Centralized process manager for tracking and cleaning up child processes
 * This is much better than using OS-level process killing
 */
export class ProcessManager {
  private static instance: ProcessManager;
  private readonly processes: Map<string, ManagedProcess> = new Map();
  private shutdownHandlersRegistered = false;

  private constructor() {
    this.registerShutdownHandlers();
  }

  public static getInstance(): ProcessManager {
    if (!ProcessManager.instance) {
      ProcessManager.instance = new ProcessManager();
    }
    return ProcessManager.instance;
  }

  /**
   * Spawn a new managed process
   */
  public async spawnProcess(
    command: string,
    options: {
      id?: string;
      cwd?: string;
      env?: Record<string, string>;
      outputFile?: string;
      showOutput?: boolean;
    } = {}
  ): Promise<ManagedProcess> {
    const id = options.id || `proc_${Date.now()}_${Math.random().toString(36).substring(7)}`;
    
    logger.debug(`Spawning managed process [${id}]: ${command}`);

    // Determine stdio configuration
    let stdio: 'inherit' | 'pipe' | ['ignore', 'pipe', 'pipe'];
    if (options.showOutput && !options.outputFile) {
      stdio = 'inherit'; // Direct to console
    } else if (options.outputFile || options.showOutput) {
      stdio = ['ignore', 'pipe', 'pipe']; // Pipe for file/dual output
    } else {
      stdio = 'pipe'; // Capture but don't show
    }

    const childProcess = spawn('bash', ['-c', command], {
      cwd: options.cwd,
      env: { ...process.env, ...options.env },
      stdio,
      detached: false, // Keep as part of our process group
    });

    // Set up output handling
    if (options.outputFile && childProcess.stdout && childProcess.stderr) {
      await this.setupOutputHandling(childProcess, options.outputFile, options.showOutput);
    }

    const managedProcess: ManagedProcess = {
      id,
      command,
      process: childProcess,
      startTime: new Date(),
      ...(options.outputFile && { outputFile: options.outputFile }),
    };

    // Track the process
    this.processes.set(id, managedProcess);

    // Handle process exit
    childProcess.on('exit', (code, signal) => {
      logger.debug(`Process [${id}] exited with code ${code}, signal ${signal}`);
      this.processes.delete(id);
    });

    // Handle process errors
    childProcess.on('error', (error) => {
      logger.error(`Process [${id}] error: ${error.message}`);
      this.processes.delete(id);
    });

    return managedProcess;
  }

  /**
   * Set up output handling for a process
   */
  private async setupOutputHandling(
    childProcess: ChildProcess,
    outputFile: string,
    showOutput?: boolean
  ): Promise<void> {
    const fs = await import('fs');
    const writeStream = fs.createWriteStream(outputFile, { flags: 'a' });

    if (showOutput) {
      // Dual output: file and console
      const { PassThrough } = await import('stream');
      
      const stdoutPassThrough = new PassThrough();
      const stderrPassThrough = new PassThrough();
      
      childProcess.stdout?.pipe(stdoutPassThrough);
      childProcess.stderr?.pipe(stderrPassThrough);
      
      stdoutPassThrough.pipe(writeStream, { end: false });
      stderrPassThrough.pipe(writeStream, { end: false });
      stdoutPassThrough.pipe(process.stdout, { end: false });
      stderrPassThrough.pipe(process.stderr, { end: false });
    } else {
      // File only
      childProcess.stdout?.pipe(writeStream);
      childProcess.stderr?.pipe(writeStream);
    }
  }

  /**
   * Kill a specific managed process
   */
  public async killProcess(id: string, signal: NodeJS.Signals = 'SIGTERM'): Promise<boolean> {
    const managedProcess = this.processes.get(id);
    if (!managedProcess) {
      logger.debug(`Process [${id}] not found or already terminated`);
      return false;
    }

    logger.debug(`Killing process [${id}] with signal ${signal}`);
    
    try {
      managedProcess.process.kill(signal);
      
      // Wait for graceful shutdown
      await this.waitForProcessExit(managedProcess.process, 5000);
      
      // If still running, force kill
      if (!managedProcess.process.killed) {
        logger.debug(`Force killing process [${id}]`);
        managedProcess.process.kill('SIGKILL');
      }
      
      this.processes.delete(id);
      return true;
    } catch (error) {
      logger.error(`Failed to kill process [${id}]: ${error}`);
      return false;
    }
  }

  /**
   * Kill all managed processes
   */
  public async killAllProcesses(): Promise<void> {
    logger.debug(`Killing ${this.processes.size} managed processes`);
    
    const killPromises = Array.from(this.processes.keys()).map(id => 
      this.killProcess(id, 'SIGTERM')
    );
    
    await Promise.all(killPromises);
    
    // Force kill any remaining processes
    const remaining = Array.from(this.processes.keys());
    if (remaining.length > 0) {
      logger.debug(`Force killing ${remaining.length} remaining processes`);
      const forceKillPromises = remaining.map(id => this.killProcess(id, 'SIGKILL'));
      await Promise.all(forceKillPromises);
    }
    
    this.processes.clear();
  }

  /**
   * Get information about managed processes
   */
  public getProcesses(): ManagedProcess[] {
    return Array.from(this.processes.values());
  }

  /**
   * Check if a process is still running
   */
  public isProcessRunning(id: string): boolean {
    const managedProcess = this.processes.get(id);
    return managedProcess !== undefined && !managedProcess.process.killed;
  }

  /**
   * Wait for a process to exit
   */
  private waitForProcessExit(process: ChildProcess, timeoutMs: number): Promise<void> {
    return new Promise((resolve) => {
      const timeout = setTimeout(() => {
        resolve();
      }, timeoutMs);

      process.on('exit', () => {
        clearTimeout(timeout);
        resolve();
      });
    });
  }

  /**
   * Register shutdown handlers to clean up processes
   */
  private registerShutdownHandlers(): void {
    if (this.shutdownHandlersRegistered) return;

    const cleanup = async () => {
      logger.info('Cleaning up managed processes...');
      await this.killAllProcesses();
    };

    // Handle various exit scenarios
    process.on('exit', () => {
      // Synchronous cleanup for process exit
      const processes = Array.from(this.processes.values());
      processes.forEach(p => {
        try {
          if (!p.process.killed) {
            p.process.kill('SIGKILL');
          }
        } catch (error) {
          // Ignore errors during cleanup as we're already shutting down
          logger.debug(`Error during process cleanup: ${error}`);
        }
      });
    });

    process.on('SIGINT', async () => {
      await cleanup();
      process.exit(0);
    });

    process.on('SIGTERM', async () => {
      await cleanup();
      process.exit(0);
    });

    process.on('uncaughtException', async (error) => {
      logger.error(`Uncaught exception: ${error.message}`);
      await cleanup();
      process.exit(1);
    });

    process.on('unhandledRejection', async (reason) => {
      logger.error(`Unhandled rejection: ${reason}`);
      await cleanup();
      process.exit(1);
    });

    this.shutdownHandlersRegistered = true;
  }
}

// Export singleton instance
export const processManager = ProcessManager.getInstance();
