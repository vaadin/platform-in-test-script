import { platform } from 'os';
import { exec, execSync, spawn, ChildProcess } from 'child_process';
import { promisify } from 'util';
import which from 'which';
import type { RuntimeEnvironment } from '../types.js';
import { logger } from './logger.js';

const execAsync = promisify(exec);

export function getRuntimeEnvironment(): RuntimeEnvironment {
  const currentPlatform = platform();
  return {
    isLinux: currentPlatform === 'linux',
    isMac: currentPlatform === 'darwin',
    isWindows: currentPlatform === 'win32',
    isGitHubActions: process.env['GITHUB_ACTIONS'] === 'true',
  };
}

export async function checkCommands(commands: string[]): Promise<boolean> {
  try {
    for (const command of commands) {
      await which(command);
      logger.debug(`Command '${command}' found`);
    }
    return true;
  } catch (error) {
    if (error instanceof Error) {
      logger.error(`Required command not found: ${error.message}`);
    }
    return false;
  }
}

export async function runCommand(
  command: string,
  options: {
    cwd?: string;
    silent?: boolean;
    env?: Record<string, string>;
    background?: boolean;
    outputFile?: string;
    verbose?: boolean;
  } = {}
): Promise<{ stdout: string; stderr: string; success: boolean; process?: ChildProcess }> {
  try {
    const { silent = false, background = false, verbose = false, outputFile, ...execOptions } = options;
    
    if (!silent && (verbose || !background)) {
      logger.debug(`Running: ${command}`);
    }

    if (background) {
      // Run command in background
      const childProcess = spawn('bash', ['-c', command], {
        stdio: outputFile ? ['ignore', 'pipe', 'pipe'] : 'inherit',
        detached: false,
        ...execOptions,
      });

      if (outputFile && childProcess.stdout && childProcess.stderr) {
        // Redirect output to file
        const fs = await import('fs');
        const writeStream = fs.createWriteStream(outputFile, { flags: 'a' });
        childProcess.stdout.pipe(writeStream);
        childProcess.stderr.pipe(writeStream);
      }

      return {
        stdout: '',
        stderr: '',
        success: true,
        process: childProcess,
      };
    } else {
      const { stdout, stderr } = await execAsync(command, {
        ...execOptions,
        env: { ...process.env, ...options.env },
      });

      if (outputFile) {
        // Append output to file
        const fs = await import('fs');
        await fs.promises.appendFile(outputFile, stdout + stderr);
      }

      return { stdout, stderr, success: true };
    }
  } catch (error) {
    const execError = error as any;
    return {
      stdout: execError.stdout || '',
      stderr: execError.stderr || '',
      success: false,
    };
  }
}

export function runCommandSync(
  command: string,
  options: {
    cwd?: string;
    silent?: boolean;
    env?: Record<string, string>;
  } = {}
): { stdout: string; stderr: string; success: boolean } {
  try {
    const { silent = false, ...execOptions } = options;
    
    if (!silent) {
      logger.debug(`Running sync: ${command}`);
    }

    const stdout = execSync(command, {
      ...execOptions,
      env: { ...process.env, ...options.env },
      encoding: 'utf8',
    });

    return { stdout, stderr: '', success: true };
  } catch (error) {
    const execError = error as any;
    return {
      stdout: execError.stdout || '',
      stderr: execError.stderr || '',
      success: false,
    };
  }
}

export async function getPids(processName: string): Promise<string[]> {
  const { stdout, success } = await runCommand(`pgrep -f "${processName}"`, { silent: true });
  
  if (!success) {
    return [];
  }

  return stdout
    .split('\n')
    .filter(pid => pid.trim() !== '')
    .map(pid => pid.trim());
}

export async function killProcess(pid: string, signal: 'TERM' | 'KILL' = 'TERM'): Promise<boolean> {
  const { success } = await runCommand(`kill -${signal} ${pid}`, { silent: true });
  return success;
}

export async function killProcessByName(processName: string): Promise<void> {
  const pids = await getPids(processName);
  
  for (const pid of pids) {
    logger.debug(`Killing process ${pid} (${processName})`);
    await killProcess(pid, 'TERM');
    
    // Wait a bit and force kill if still running
    await sleep(2000);
    const stillRunning = await getPids(processName);
    if (stillRunning.includes(pid)) {
      await killProcess(pid, 'KILL');
    }
  }
}

export function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

export function formatTime(seconds: number): string {
  const minutes = Math.floor(seconds / 60);
  const remainingSeconds = seconds % 60;
  return `${minutes}m ${remainingSeconds}s`;
}

export function ensureArray<T>(value: T | T[]): T[] {
  return Array.isArray(value) ? value : [value];
}

export function parseBoolean(value: string | boolean | undefined): boolean {
  if (typeof value === 'boolean') return value;
  if (typeof value === 'string') {
    return value.toLowerCase() === 'true' || value === '1';
  }
  return false;
}

export function sanitizeFileName(name: string): string {
  return name.replace(/[^a-zA-Z0-9.-]/g, '_');
}

export async function runCommandInBackground(
  command: string,
  options: {
    cwd?: string;
    env?: Record<string, string>;
  } = {}
): Promise<any> {
  logger.debug(`Running in background: ${command}`);
  
  const args = command.split(' ');
  const cmd = args.shift()!;
  
  const childProcess = spawn(cmd, args, {
    ...options,
    env: { ...process.env, ...options.env },
    detached: true,
    stdio: 'pipe',
  });

  return childProcess;
}

export async function isPortBusy(port: number): Promise<boolean> {
  try {
    const { stdout } = await runCommand(`lsof -ti:${port}`, { silent: true });
    return stdout.trim() !== '';
  } catch {
    return false;
  }
}

export async function killProcessesByPort(port: number): Promise<void> {
  const result = await runCommand(`lsof -ti:${port} | xargs kill -9 2>/dev/null || true`);
  if (!result.success) {
    logger.debug(`No processes found on port ${port}`);
  }
}

export async function killProcesses(): Promise<void> {
  // Kill common development server processes
  const commands = [
    'pkill -f "spring-boot:run" || true',
    'pkill -f "mvn.*jetty:run" || true',
    'pkill -f "gradle.*bootRun" || true',
    'pkill -f "quarkus:dev" || true',
  ];

  for (const cmd of commands) {
    await runCommand(cmd, { silent: true });
  }

  // Give processes time to shut down
  await new Promise(resolve => setTimeout(resolve, 2000));
}

export async function waitForServer(url: string, timeoutSeconds: number): Promise<void> {
  const startTime = Date.now();
  const timeoutMs = timeoutSeconds * 1000;

  while (Date.now() - startTime < timeoutMs) {
    try {
      const response = await fetch(url, { 
        method: 'GET',
        signal: AbortSignal.timeout(5000) // 5 second timeout per request
      });
      
      if (response.ok) {
        logger.info(`✓ Server is ready at ${url}`);
        return;
      }
    } catch {
      // Server not ready yet, continue waiting
    }

    await new Promise(resolve => setTimeout(resolve, 2000));
  }

  throw new Error(`Server at ${url} did not start within ${timeoutSeconds} seconds`);
}
