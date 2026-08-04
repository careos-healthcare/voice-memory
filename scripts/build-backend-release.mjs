#!/usr/bin/env node
import { cp, mkdir, readFile, rm, symlink, writeFile } from "node:fs/promises";
import path from "node:path";
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const releaseRoot = path.join(root, ".backend-release");
const policy = JSON.parse(
  await readFile(
    path.join(root, "config/release/backend-capabilities.json"),
    "utf8",
  ),
);

await rm(releaseRoot, { recursive: true, force: true });
await mkdir(path.join(releaseRoot, "app"), { recursive: true });

for (const input of policy.releaseInputs) {
  if (input === "app/api") {
    await cp(path.join(root, input), path.join(releaseRoot, input), {
      recursive: true,
    });
    continue;
  }
  await cp(path.join(root, input), path.join(releaseRoot, input), {
    recursive: true,
  });
}

const stagedTsconfig = {
  compilerOptions: {
    target: "ES2020",
    lib: ["dom", "dom.iterable", "esnext"],
    skipLibCheck: true,
    strict: true,
    noEmit: true,
    esModuleInterop: true,
    module: "esnext",
    moduleResolution: "bundler",
    resolveJsonModule: true,
    isolatedModules: true,
    jsx: "react-jsx",
    paths: { "@/*": ["./*"] },
    plugins: [{ name: "next" }],
  },
  include: [
    "next-env.d.ts",
    "app/api/**/*.ts",
    "backend/**/*.ts",
    ".next/types/**/*.ts",
  ],
  exclude: ["node_modules"],
};
await writeFile(
  path.join(releaseRoot, "tsconfig.json"),
  `${JSON.stringify(stagedTsconfig, null, 2)}\n`,
);

await writeFile(
  path.join(releaseRoot, "next.config.ts"),
  `import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  outputFileTracingRoot: process.cwd(),
  serverExternalPackages: ["pg"],
  turbopack: { root: process.cwd() },
};

export default nextConfig;
`,
);

await symlink("../node_modules", path.join(releaseRoot, "node_modules"), "dir");

await run(process.execPath, [
  path.join(root, "node_modules/next/dist/bin/next"),
  "build",
  "--webpack",
], releaseRoot);

await run(process.execPath, [
  path.join(root, "scripts/validate-release-graph.mjs"),
  "--artifact",
], root);

for (const generatedInput of [
  "app",
  "backend",
  "lib",
  "middleware.ts",
  "node_modules",
  "package-lock.json",
  "tsconfig.json",
  "types",
]) {
  await rm(path.join(releaseRoot, generatedInput), {
    recursive: true,
    force: true,
  });
}

console.log(`Backend release artifact written to ${path.relative(root, releaseRoot)}`);

function run(command, args, cwd) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, { cwd, stdio: "inherit", env: process.env });
    child.once("error", reject);
    child.once("exit", (code, signal) => {
      if (code === 0) {
        resolve();
      } else {
        reject(
          new Error(
            `${path.basename(command)} exited with ${code ?? `signal ${signal}`}`,
          ),
        );
      }
    });
  });
}
