import { Command } from 'commander';
import { DEFAULT_CONFIG, PRESETS, DEMOS } from '../constants.js';
import type { PitConfig } from '../types.js';
import { logger } from '../utils/logger.js';

export function createProgram(): Command {
  const program = new Command();

  program
    .name('pit')
    .description('Platform in Test (PiT) - Vaadin testing suite')
    .version('1.0.0')
    .option('--vaadin-version <string>', 'Vaadin version to test', DEFAULT_CONFIG.version)
    .option('--demos', 'Run all demo projects')
    .option('--generated', 'Run all generated projects (start and archetypes)')
    .option('--port <number>', 'HTTP port for the servlet container', String(DEFAULT_CONFIG.port))
    .option('--timeout <number>', 'Time in secs to wait for server to start', String(DEFAULT_CONFIG.timeout))
    .option('--jdk <number>', 'Use a specific JDK version to run the tests')
    .option('--verbose', 'Show server output (default silent)', DEFAULT_CONFIG.verbose)
    .option('--offline', 'Do not remove already downloaded projects, and do not use network for mvn', DEFAULT_CONFIG.offline)
    .option('--interactive', 'Play a bell and ask user to manually test the application', DEFAULT_CONFIG.interactive)
    .option('--skip-tests', 'Skip UI Tests (default run tests)', DEFAULT_CONFIG.skipTests)
    .option('--skip-current', 'Skip running build in current version', DEFAULT_CONFIG.skipCurrent)
    .option('--skip-prod', 'Skip production validations', DEFAULT_CONFIG.skipProd)
    .option('--skip-dev', 'Skip dev-mode validations', DEFAULT_CONFIG.skipDev)
    .option('--skip-clean', 'Do not clean maven cache', DEFAULT_CONFIG.skipClean)
    .option('--skip-helm', 'Do not re-install control-center with helm', DEFAULT_CONFIG.skipHelm)
    .option('--skip-pw', 'Do not run playwright tests', DEFAULT_CONFIG.skipPw)
    .option('--cluster <name>', 'Run tests in an existing k8s cluster', DEFAULT_CONFIG.cluster)
    .option('--vendor <name>', 'Use a specific cluster vendor (dd, kind, do)', DEFAULT_CONFIG.vendor)
    .option('--keep-cc', 'Keep control-center running after tests', DEFAULT_CONFIG.keepCc)
    .option('--keep-apps', 'Keep installed apps in control-center', DEFAULT_CONFIG.keepApps)
    .option('--proxy-cc', 'Forward port 443 from k8s cluster to localhost', DEFAULT_CONFIG.proxyCc)
    .option('--events-cc', 'Display events from control-center', DEFAULT_CONFIG.eventsCc)
    .option('--cc-version <string>', 'Install this version for current', DEFAULT_CONFIG.ccVersion)
    .option('--skip-build', 'Skip building the docker images for control-center', DEFAULT_CONFIG.skipBuild)
    .option('--delete-cluster', 'Delete the cluster/s', DEFAULT_CONFIG.deleteCluster)
    .option('--dashboard <action>', 'Install kubernetes dashboard (install, uninstall)', DEFAULT_CONFIG.dashboard)
    .option('--pnpm', 'Use pnpm instead of npm', DEFAULT_CONFIG.pnpm)
    .option('--vite', 'Use vite instead of webpack', DEFAULT_CONFIG.vite)
    .option('--list', 'Show the list of available starters')
    .option('--hub', 'Use selenium hub instead of local chrome', DEFAULT_CONFIG.hub)
    .option('--commit', 'Commit changes to the base branch', DEFAULT_CONFIG.commit)
    .option('--test', 'Show steps and commands but don\'t run them', DEFAULT_CONFIG.test)
    .option('--git-ssh', 'Use git-ssh instead of https', DEFAULT_CONFIG.gitSsh)
    .option('--headless', 'Run the browser in headless mode', DEFAULT_CONFIG.headless)
    .option('--headed', 'Run the browser in headed mode', DEFAULT_CONFIG.headed)
    .option('--debug', 'Enable debug mode with extra logging', DEFAULT_CONFIG.debug)
    .option('--run-pw', 'Skip setup and only run Playwright tests (assumes server is already running)', DEFAULT_CONFIG.runPw)
    .option('--ghtk <token>', 'GitHub personal access token (sets GHTK environment variable)')
    .option('--gh-token <token>', 'GitHub personal access token (alias for --ghtk)')
    .option('--function <function>', 'Run only one function')
    .option('--starters <list>', 'List of demos or presets separated by comma', DEFAULT_CONFIG.starters);

  return program;
}

export function parseArguments(args: string[]): PitConfig {
  const program = createProgram();
  program.parse(args);
  const options = program.opts() as any;

  // Handle special cases
  if (options['list']) {
    showStartersList();
    process.exit(0);
  }

  if (options['demos']) {
    options['starters'] = DEMOS.join(',');
  }

  if (options['generated']) {
    options['starters'] = PRESETS.join(',');
  }

  // Handle vendor-specific cluster naming
  if (options['vendor'] === 'dd') {
    options['cluster'] = 'docker-desktop';
  }

  // Handle keep-apps implies keep-cc
  if (options['keepApps']) {
    options['keepCc'] = true;
  }

  // Handle skip-helm implications
  if (options['skipHelm']) {
    options['offline'] = true;
    options['keepCc'] = true;
  }

  // Handle headless/headed logic
  let headlessMode = DEFAULT_CONFIG.headless; // Default value (true)
  if (options['headless'] === true) {
    headlessMode = true;
  } else if (options['headed'] === true) {
    headlessMode = false;
  }

  // Handle GitHub token arguments
  if (options['ghtk'] || options['ghToken']) {
    const token = options['ghtk'] || options['ghToken'];
    process.env['GHTK'] = token;
  }

  const config: PitConfig = {
    port: parseInt(options['port']) || DEFAULT_CONFIG.port,
    timeout: parseInt(options['timeout']) || DEFAULT_CONFIG.timeout,
    version: options['vaadinVersion'] || DEFAULT_CONFIG.version,
    jdk: options['jdk'],
    verbose: Boolean(options['verbose']),
    offline: Boolean(options['offline']),
    interactive: Boolean(options['interactive']),
    skipTests: Boolean(options['skipTests']),
    skipCurrent: Boolean(options['skipCurrent']),
    skipDev: Boolean(options['skipDev']),
    skipProd: Boolean(options['skipProd']),
    skipPw: Boolean(options['skipPw']),
    skipClean: Boolean(options['skipClean']),
    skipHelm: Boolean(options['skipHelm']),
    skipBuild: Boolean(options['skipBuild']),
    cluster: options['cluster'] || DEFAULT_CONFIG.cluster,
    vendor: options['vendor'] || DEFAULT_CONFIG.vendor,
    keepCc: Boolean(options['keepCc']),
    keepApps: Boolean(options['keepApps']),
    proxyCc: Boolean(options['proxyCc']),
    eventsCc: Boolean(options['eventsCc']),
    ccVersion: options['ccVersion'] || DEFAULT_CONFIG.ccVersion,
    deleteCluster: Boolean(options['deleteCluster']),
    dashboard: options['dashboard'] || DEFAULT_CONFIG.dashboard,
    pnpm: Boolean(options['pnpm']),
    vite: Boolean(options['vite']),
    hub: Boolean(options['hub']),
    commit: Boolean(options['commit']),
    test: Boolean(options['test']),
    gitSsh: Boolean(options['gitSsh']),
    headless: headlessMode,
    headed: Boolean(options['headed']),
    debug: Boolean(options['debug']),
    runPw: Boolean(options['runPw']),
    starters: options['starters'] || DEFAULT_CONFIG.starters,
    runFunction: options['function'],
  };

  return config;
}

function showStartersList(): void {
  logger.separator('Available Starters');
  
  logger.info('Presets (generated from start.vaadin.com or archetypes):');
  PRESETS.forEach(preset => {
    logger.info(`  · ${preset}`);
  });

  logger.info('\nDemos (from GitHub repositories):');
  DEMOS.forEach(demo => {
    logger.info(`  · ${demo}`);
  });
}

export function validateConfig(config: PitConfig): { valid: boolean; errors: string[] } {
  const errors: string[] = [];

  // Validate port
  if (config.port < 1 || config.port > 65535) {
    errors.push('Port must be between 1 and 65535');
  }

  // Validate timeout
  if (config.timeout < 1) {
    errors.push('Timeout must be positive');
  }

  // Validate vendor
  if (!['dd', 'kind', 'do'].includes(config.vendor)) {
    errors.push('Vendor must be one of: dd, kind, do');
  }

  // Validate dashboard action
  if (!['install', 'uninstall'].includes(config.dashboard)) {
    errors.push('Dashboard action must be: install or uninstall');
  }

  // Validate starters
  if (config.starters) {
    const starterNames = config.starters.split(',').map(s => s.trim());
    const allStarters = [...PRESETS, ...DEMOS];
    
    for (const starter of starterNames) {
      const starterBase = starter.split(':')[0]; // Handle variants like "bookstore-example:rtl-demo"
      if (starterBase && !allStarters.some(s => s.includes(starterBase))) {
        errors.push(`Unknown starter: ${starter}`);
      }
    }
  }

  return { valid: errors.length === 0, errors };
}
