#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const ACCOUNT_PAGE = path.join(ROOT, "apps/web/app/account/page.tsx");
const REVISIT_COPY = path.join(ROOT, "packages/shared/lib/refinement/revisit-reward-copy.ts");

if (!fs.existsSync(REVISIT_COPY)) {
  console.error("Account route validation failed — missing lib/refinement/revisit-reward-copy.ts");
  process.exit(1);
}

const revisitCopySource = fs.readFileSync(REVISIT_COPY, "utf8");
if (revisitCopySource.includes('from "@/lib/')) {
  console.error(
    "Account route validation failed — revisit-reward-copy must stay import-free.",
  );
  process.exit(1);
}

const accountSource = fs.readFileSync(ACCOUNT_PAGE, "utf8");

const forbiddenImports = [
  "@/lib/refinement/knows-me-moments",
  "@/lib/refinement/revisit-experience",
  "@/lib/refinement/quiet-presentation",
  "@/lib/monetization/monetization-observation",
];

for (const token of forbiddenImports) {
  const staticImport = new RegExp(`from ["']${token.replace(/\//g, "\\/")}["']`);
  if (staticImport.test(accountSource)) {
    console.error(
      `Account route validation failed — app/account/page.tsx must not statically import ${token}`,
    );
    process.exit(1);
  }
}

const observation = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/monetization/monetization-observation.ts"),
  "utf8",
);
if (observation.includes('from "@/lib/debug/emotional-legitimacy-review"')) {
  console.error(
    "Account route validation failed — monetization-observation must lazy-load emotional-legitimacy-review.",
  );
  process.exit(1);
}

console.log("Account route restraint validation passed.");
