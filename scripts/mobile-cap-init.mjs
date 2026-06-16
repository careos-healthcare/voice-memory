#!/usr/bin/env node
/**
 * First-time / refresh Capacitor native projects.
 * Set CAPACITOR_SERVER_URL for local WebView testing (e.g. http://localhost:3000).
 */
import { spawnSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

function run(cmd, args) {
  const r = spawnSync(cmd, args, { cwd: ROOT, stdio: "inherit", shell: false });
  if (r.status !== 0) process.exit(r.status ?? 1);
}

console.log("ArchiveMe — Capacitor init/sync");
console.log(
  "Server URL:",
  process.env.CAPACITOR_SERVER_URL ||
    process.env.NEXT_PUBLIC_APP_URL ||
    "(default from capacitor.config.ts)",
);
run("npx", ["cap", "sync"]);
console.log("\nNext: npm run mobile:ios  |  npm run mobile:android");
console.log("Dev:  CAPACITOR_SERVER_URL=http://localhost:3000 npm run dev");
console.log("      CAPACITOR_SERVER_URL=http://localhost:3000 npm run mobile:sync");
