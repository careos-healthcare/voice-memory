#!/usr/bin/env node
import * as esbuild from "esbuild";
import fs from "node:fs";
import { mkdir } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const outfile = path.join(root, "dist/main.js");

await mkdir(path.dirname(outfile), { recursive: true });

const result = await esbuild.build({
  entryPoints: [path.join(root, "server.entry.ts")],
  outfile,
  bundle: true,
  platform: "node",
  target: "node22",
  format: "cjs",
  sourcemap: true,
  tsconfig: path.join(root, "tsconfig.json"),
  packages: "external",
  logLevel: "info",
});

if (result.errors.length > 0) {
  process.exit(1);
}

const bundle = fs.readFileSync(outfile, "utf8");
const requiredMarkers = [
  "attachLiveAudioWebSocketUpgrade",
  "Live audio proxy",
  "authenticateLiveAudioWebSocketUpgrade",
  "registerGracefulShutdown",
  "coordinator_disconnect",
];
for (const marker of requiredMarkers) {
  if (!bundle.includes(marker)) {
    throw new Error(`dist/main.js missing expected marker: ${marker}`);
  }
}

console.log("Server bundle written to dist/main.js");
