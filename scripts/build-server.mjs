#!/usr/bin/env node
import * as esbuild from "esbuild";
import fs from "node:fs";
import { mkdir } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const outfile = path.join(root, "dist/main.js");
const serverOnlyShimPlugin = {
  name: "server-only-shim",
  setup(build) {
    build.onResolve({ filter: /^server-only$/ }, () => ({
      path: "server-only",
      namespace: "server-only-shim",
    }));
    build.onLoad({ filter: /.*/, namespace: "server-only-shim" }, () => ({
      contents: "",
      loader: "js",
    }));
  },
};

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
  plugins: [serverOnlyShimPlugin],
  logLevel: "info",
});

if (result.errors.length > 0) {
  process.exit(1);
}

const bundle = fs.readFileSync(outfile, "utf8");
const requiredMarkers = ["registerGracefulShutdown"];
for (const marker of requiredMarkers) {
  if (!bundle.includes(marker)) {
    throw new Error(`dist/main.js missing expected marker: ${marker}`);
  }
}

// The live-audio and cloud-relay WebSocket surfaces are held out of V1. If they
// reappear in the bundle, an experimental dependency has re-entered production.
const forbiddenMarkers = [
  "attachLiveAudioWebSocketUpgrade",
  "attachCloudRelayWebSocketUpgrade",
  "authenticateLiveAudioWebSocketUpgrade",
];
for (const marker of forbiddenMarkers) {
  if (bundle.includes(marker)) {
    throw new Error(
      `dist/main.js contains held-out experimental marker: ${marker}`,
    );
  }
}

console.log("Server bundle written to dist/main.js");
