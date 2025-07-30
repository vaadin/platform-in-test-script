import { parseArguments, validateConfig } from '../cli/args.js';
import { PRESETS, DEMOS } from '../constants.js';

describe('PiT Configuration', () => {
  test('should parse basic arguments correctly', () => {
    const args = ['node', 'pit', '--verbose', '--port=9090', '--test'];
    const config = parseArguments(args);
    
    expect(config.verbose).toBe(true);
    expect(config.port).toBe(9090);
    expect(config.test).toBe(true);
  });

  test('should validate correct configuration', () => {
    const config = parseArguments(['node', 'pit', '--port=8080']);
    const validation = validateConfig(config);
    
    expect(validation.valid).toBe(true);
    expect(validation.errors).toHaveLength(0);
  });

  test('should detect invalid port', () => {
    const config = parseArguments(['node', 'pit', '--port=99999']);
    const validation = validateConfig(config);
    
    expect(validation.valid).toBe(false);
    expect(validation.errors).toContain('Port must be between 1 and 65535');
  });

  test('should handle demos flag', () => {
    const config = parseArguments(['node', 'pit', '--demos']);
    
    expect(config.starters).toBe(DEMOS.join(','));
  });

  test('should handle generated flag', () => {
    const config = parseArguments(['node', 'pit', '--generated']);
    
    expect(config.starters).toBe(PRESETS.join(','));
  });
});

describe('Constants', () => {
  test('should have valid presets list', () => {
    expect(PRESETS).toBeDefined();
    expect(PRESETS.length).toBeGreaterThan(0);
    expect(PRESETS).toContain('latest-java');
  });

  test('should have valid demos list', () => {
    expect(DEMOS).toBeDefined();
    expect(DEMOS.length).toBeGreaterThan(0);
    expect(DEMOS).toContain('bookstore-example');
  });
});
