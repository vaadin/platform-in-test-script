import chalk from 'chalk';
import type { LogLevel } from '../types.js';

export class Logger {
  private static instance: Logger;
  private verbose = false;
  private debugMode = false;

  private constructor() {}

  static getInstance(): Logger {
    if (!Logger.instance) {
      Logger.instance = new Logger();
    }
    return Logger.instance;
  }

  setVerbose(verbose: boolean): void {
    this.verbose = verbose;
  }

  setDebug(debug: boolean): void {
    this.debugMode = debug;
  }

  setOptions(verbose: boolean, debug: boolean): void {
    this.verbose = verbose;
    this.debugMode = debug;
  }

  isDebugMode(): boolean {
    return this.debugMode;
  }

  info(message: string): void {
    console.log(chalk.blue('ℹ') + chalk.reset(' ' + message) + chalk.reset());
  }

  warn(message: string): void {
    console.log(chalk.yellow('⚠') + chalk.reset(' ' + message) + chalk.reset());
  }

  error(message: string): void {
    console.log(chalk.red('✗') + chalk.reset(' ' + message) + chalk.reset());
  }

  success(message: string): void {
    console.log(chalk.green('✓') + chalk.reset(' ' + message) + chalk.reset());
  }

  debug(message: string): void {
    if (this.verbose || this.debugMode) {
      console.log(chalk.gray('🐛') + chalk.reset(' ' + message) + chalk.reset());
    }
  }

  bold(message: string): void {
    console.log(chalk.bold(message));
  }

  log(message: string, level: LogLevel = 'info'): void {
    switch (level) {
      case 'info':
        this.info(message);
        break;
      case 'warn':
        this.warn(message);
        break;
      case 'error':
        this.error(message);
        break;
      case 'debug':
        this.debug(message);
        break;
    }
  }

  separator(title?: string): void {
    const line = '='.repeat(80);
    if (title) {
      const paddedTitle = ` ${title} `;
      const padding = Math.max(0, (line.length - paddedTitle.length) / 2);
      const leftPad = '='.repeat(Math.floor(padding));
      const rightPad = '='.repeat(Math.ceil(padding));
      console.log(chalk.cyan(`${leftPad}${paddedTitle}${rightPad}`));
    } else {
      console.log(chalk.cyan(line));
    }
  }

  printTime(startTime: number): void {
    const duration = Math.floor((Date.now() - startTime) / 1000);
    const minutes = Math.floor(duration / 60);
    const seconds = duration % 60;
    this.info(`Total execution time: ${minutes}m ${seconds}s`);
  }
}

export const logger = Logger.getInstance();
