import "server-only";

import fs from "node:fs";
import path from "node:path";

const DATA_ROOT = path.resolve(process.cwd(), ".data");

/**
 * Resolves a path under the data root and verifies it cannot escape it
 * (no `..` traversal, no absolute-path segment override). Does not touch
 * the filesystem — safe to call before deciding whether to create or
 * delete anything.
 */
export function resolveDataPath(...segments: string[]): string {
  const target = path.resolve(DATA_ROOT, ...segments);
  const relative = path.relative(DATA_ROOT, target);
  if (relative.startsWith("..") || path.isAbsolute(relative)) {
    throw new Error("Refusing to resolve a data path outside the data root.");
  }
  return target;
}

export function ensureDataDir(...segments: string[]): string {
  const dir = resolveDataPath(...segments);
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

/**
 * Removes a path under the data root, idempotently (missing path is a no-op,
 * not an error) and safely:
 *   - the target is validated to stay under DATA_ROOT via `resolveDataPath`.
 *   - if the target itself is a symlink, only the link is unlinked — its
 *     target is never followed/recursed into, so a symlink planted at a
 *     user's data path cannot be used to delete something outside the data
 *     root.
 * Returns true if something was actually removed.
 */
export function removeDataPath(...segments: string[]): boolean {
  const target = resolveDataPath(...segments);

  let stat: fs.Stats;
  try {
    stat = fs.lstatSync(target);
  } catch {
    return false;
  }

  if (stat.isSymbolicLink()) {
    fs.unlinkSync(target);
    return true;
  }

  fs.rmSync(target, { recursive: true, force: true });
  return true;
}
