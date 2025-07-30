export interface PitConfig {
  port: number;
  timeout: number;
  version: string;
  jdk?: string;
  verbose: boolean;
  offline: boolean;
  interactive: boolean;
  skipTests: boolean;
  skipCurrent: boolean;
  skipDev: boolean;
  skipProd: boolean;
  skipPw: boolean;
  skipClean: boolean;
  skipHelm: boolean;
  skipBuild: boolean;
  cluster: string;
  vendor: 'dd' | 'kind' | 'do';
  keepCc: boolean;
  keepApps: boolean;
  proxyCc: boolean;
  eventsCc: boolean;
  ccVersion: string;
  deleteCluster: boolean;
  dashboard: 'install' | 'uninstall';
  pnpm: boolean;
  vite: boolean;
  hub: boolean;
  commit: boolean;
  test: boolean;
  gitSsh: boolean;
  headless: boolean;
  headed: boolean;
  starters: string;
  runFunction?: string;
}

export interface StarterInfo {
  name: string;
  type: 'preset' | 'demo';
  variants?: string[];
}

export interface TestResult {
  name: string;
  success: boolean;
  error?: string;
  duration: number;
  logFiles?: string[];
}

export interface RuntimeEnvironment {
  isLinux: boolean;
  isMac: boolean;
  isWindows: boolean;
  isGitHubActions: boolean;
}

export type LogLevel = 'info' | 'warn' | 'error' | 'debug';

export interface LogEntry {
  level: LogLevel;
  message: string;
  timestamp: Date;
}

export type StarterType = 'preset' | 'demo';
export type TestMode = 'dev' | 'prod';
export type AppType = 'current' | 'next';
