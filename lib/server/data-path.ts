import "server-only";

import fs from "node:fs";
import path from "node:path";

const DATA_ROOT = path.join(process.cwd(), ".data");

export function ensureDataDir(...segments: string[]): string {
  const dir = path.join(DATA_ROOT, ...segments);
  fs.mkdirSync(dir, { recursive: true });
  return dir;
}

export function readJsonFile<T>(filePath: string, fallback: T): T {
  try {
    if (!fs.existsSync(filePath)) return fallback;
    return JSON.parse(fs.readFileSync(filePath, "utf8")) as T;
  } catch {
    return fallback;
  }
}

export function writeJsonFile(filePath: string, value: unknown): void {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, JSON.stringify(value, null, 2), "utf8");
}
