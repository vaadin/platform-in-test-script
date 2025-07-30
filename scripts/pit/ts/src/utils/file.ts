import fs from 'fs-extra';
import path from 'path';
import { glob } from 'glob';
import { logger } from './logger.js';

export async function ensureDirectory(dirPath: string): Promise<void> {
  try {
    await fs.ensureDir(dirPath);
    logger.debug(`Directory ensured: ${dirPath}`);
  } catch (error) {
    logger.error(`Failed to create directory ${dirPath}: ${error}`);
    throw error;
  }
}

export async function removeDirectory(dirPath: string): Promise<void> {
  try {
    await fs.remove(dirPath);
    logger.debug(`Directory removed: ${dirPath}`);
  } catch (error) {
    logger.debug(`Failed to remove directory ${dirPath}: ${error}`);
  }
}

export async function copyFile(src: string, dest: string): Promise<void> {
  try {
    await fs.copy(src, dest);
    logger.debug(`File copied: ${src} -> ${dest}`);
  } catch (error) {
    logger.error(`Failed to copy file ${src} to ${dest}: ${error}`);
    throw error;
  }
}

export async function readJsonFile<T>(filePath: string): Promise<T | null> {
  try {
    const content = await fs.readJson(filePath);
    return content as T;
  } catch (error) {
    logger.debug(`Failed to read JSON file ${filePath}: ${error}`);
    return null;
  }
}

export async function writeJsonFile(filePath: string, data: any): Promise<void> {
  try {
    await fs.writeJson(filePath, data, { spaces: 2 });
    logger.debug(`JSON file written: ${filePath}`);
  } catch (error) {
    logger.error(`Failed to write JSON file ${filePath}: ${error}`);
    throw error;
  }
}

export async function readTextFile(filePath: string): Promise<string | null> {
  try {
    const content = await fs.readFile(filePath, 'utf8');
    return content;
  } catch (error) {
    logger.debug(`Failed to read text file ${filePath}: ${error}`);
    return null;
  }
}

export async function writeTextFile(filePath: string, content: string): Promise<void> {
  try {
    await fs.writeFile(filePath, content, 'utf8');
    logger.debug(`Text file written: ${filePath}`);
  } catch (error) {
    logger.error(`Failed to write text file ${filePath}: ${error}`);
    throw error;
  }
}

export async function fileExists(filePath: string): Promise<boolean> {
  try {
    await fs.access(filePath);
    return true;
  } catch {
    return false;
  }
}

export async function findFiles(pattern: string, cwd?: string): Promise<string[]> {
  try {
    const options = cwd ? { cwd } : {};
    const files = await glob(pattern, options);
    return files;
  } catch (error) {
    logger.error(`Failed to find files with pattern ${pattern}: ${error}`);
    return [];
  }
}

export function getAbsolutePath(relativePath: string): string {
  return path.resolve(relativePath);
}

export function joinPaths(...paths: string[]): string {
  return path.join(...paths);
}

export function getFileName(filePath: string): string {
  return path.basename(filePath);
}

export function getDirectoryName(filePath: string): string {
  return path.dirname(filePath);
}

export function getFileExtension(filePath: string): string {
  return path.extname(filePath);
}

export async function setPropertyInFile(
  filePath: string,
  property: string,
  value: string
): Promise<void> {
  try {
    let content = await readTextFile(filePath);
    if (!content) {
      content = '';
    }

    const lines = content.split('\n');
    let found = false;

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i]?.trim();
      if (line?.startsWith(`${property}=`)) {
        lines[i] = `${property}=${value}`;
        found = true;
        break;
      }
    }

    if (!found) {
      lines.push(`${property}=${value}`);
    }

    await writeTextFile(filePath, lines.join('\n'));
    logger.debug(`Property ${property} set to ${value} in ${filePath}`);
  } catch (error) {
    logger.error(`Failed to set property in file ${filePath}: ${error}`);
    throw error;
  }
}

// Aliases for consistency with validator expectations
export const readFile = readTextFile;
export const writeFile = writeTextFile;
