#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const pagePath = path.join(ROOT, "app/page.tsx");
const copyPath = path.join(ROOT, "lib/product-copy.ts");
const recognitionPath = path.join(ROOT, "lib/product/recognition-copy.ts");

for (const rel of [pagePath, copyPath, recognitionPath]) {
  if (!fs.existsSync(rel)) {
    console.error(`Homepage clarity validation failed — missing ${rel}`);
    process.exit(1);
  }
}

const page = fs.readFileSync(pagePath, "utf8");
const copy = fs.readFileSync(copyPath, "utf8");
const recognition = fs.readFileSync(recognitionPath, "utf8");
const copySources = `${copy}\n${recognition}`;

const clarityCopyPath = path.join(ROOT, "lib/product/product-clarity-copy.ts");
const clarityCopy = fs.existsSync(clarityCopyPath)
  ? fs.readFileSync(clarityCopyPath, "utf8")
  : "";

const required = [
  "HOMEPAGE_CLARITY",
  "See the patterns you keep missing.",
  "ChatGPT answers today. ArchiveMe shows what keeps repeating across your life.",
  "HomepageChatGptComparison",
  "ProductDemoStory",
  "PatternActivationProgress",
  "criticism means you're failing",
];

for (const token of required) {
  if (
    !page.includes(token) &&
    !copySources.includes(token) &&
    !clarityCopy.includes(token)
  ) {
    console.error(`Homepage clarity validation failed — missing ${token}`);
    process.exit(1);
  }
}

const bannedOnHomepage = [
  "emotional architecture",
  "sacredness",
  "territories",
  "founder",
  "mystical",
  "intelligence engine",
  "patterns may emerge",
  "unlock your insights",
];

for (const phrase of bannedOnHomepage) {
  if (page.toLowerCase().includes(phrase.toLowerCase())) {
    console.error(`Homepage clarity validation failed — banned phrase on homepage: ${phrase}`);
    process.exit(1);
  }
}

if (page.includes("PRODUCT_WEDGE_LINE") || page.includes("NOT_AI_JOURNAL_LINE")) {
  console.error(
    "Homepage clarity validation failed — de-emphasize duplicate wedge/not-AI lines in hero.",
  );
  process.exit(1);
}

console.log("Homepage clarity validation passed.");
