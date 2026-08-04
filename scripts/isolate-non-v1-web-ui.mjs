import { mkdir, readdir, rename } from "node:fs/promises";
import path from "node:path";
import process from "node:process";

const root = process.cwd();
const appRoot = path.join(root, "app");
const destinationRoot = path.join(
  root,
  "experiments/archive_me_legacy_web/app",
);

async function collectPages(directory) {
  const result = [];
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const absolute = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      result.push(...(await collectPages(absolute)));
    } else if (entry.name === "page.tsx") {
      result.push(absolute);
    }
  }
  return result;
}

const pages = await collectPages(appRoot);
for (const source of pages) {
  const relative = path.relative(appRoot, source);
  const destination = path.join(destinationRoot, relative);
  await mkdir(path.dirname(destination), { recursive: true });
  await rename(source, destination);
}

console.log(
  JSON.stringify(
    {
      isolatedConsumerPages: pages.length,
      destination: "experiments/archive_me_legacy_web/app",
    },
    null,
    2,
  ),
);
