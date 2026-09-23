import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import test from "node:test";

import { archiveDesignTokens } from "./archive-design-tokens.ts";

function repoRoot(): string {
  const cwd = process.cwd();
  if (cwd.endsWith("/apps/web")) return join(cwd, "../..");
  return cwd;
}

test("Flutter and web themes carry the same archive tokens", () => {
  const root = repoRoot();
  const dart = readFileSync(
    join(root, "apps/mobile/lib/theme/archive_design_tokens.dart"),
    "utf8",
  ).toUpperCase();
  const css = readFileSync(join(root, "apps/web/app/globals.css"), "utf8").toLowerCase();
  const tailwind = readFileSync(join(root, "apps/web/tailwind.config.ts"), "utf8");

  for (const hex of Object.values(archiveDesignTokens.color.light)) {
    const bare = hex.slice(1);
    assert.match(dart, new RegExp(bare, "i"));
    assert.match(css, new RegExp(bare, "i"));
  }

  for (const hex of [
    archiveDesignTokens.color.dark.background,
    archiveDesignTokens.color.dark.foreground,
    archiveDesignTokens.color.dark.muted,
    archiveDesignTokens.color.dark.accent,
  ]) {
    assert.match(dart, new RegExp(hex.slice(1), "i"));
  }

  for (const size of Object.values(archiveDesignTokens.space)) {
    assert.match(dart, new RegExp(`= ${size}\\.0`));
    assert.match(css, new RegExp(`${size}px`));
  }

  for (const role of Object.values(archiveDesignTokens.type)) {
    assert.match(dart, new RegExp(`= ${role.size}\\.0`));
    assert.match(css, new RegExp(`${role.size}px`));
  }

  assert.match(tailwind, /archive-design-tokens/);
  assert.match(css, /@config "\.\.\/tailwind\.config\.ts"/);

  assert.equal(archiveDesignTokens.primary[600], "#2563EB");
  assert.equal(archiveDesignTokens.primary[700], "#1D4ED8");
  assert.equal(archiveDesignTokens.neutral[50], "#FAFAFA");
  assert.equal(archiveDesignTokens.neutral[900], "#171717");
  assert.equal(archiveDesignTokens.color.light.background, "#F8F6F1");
  for (let step = 1; step <= 16; step += 1) {
    const key = String(step) as unknown as keyof typeof archiveDesignTokens.spacing;
    assert.equal(archiveDesignTokens.spacing[key], step * 4);
  }

  const tokens = readFileSync(
    join(root, "apps/mobile/lib/theme/app_tokens.dart"),
    "utf8",
  ).toUpperCase();
  assert.match(tokens, /PRIMARY600 = COLOR\(0XFF2563EB\)/);
  assert.match(tokens, /PRIMARY700 = COLOR\(0XFF1D4ED8\)/);
  assert.match(tokens, /NEUTRAL50 = COLOR\(0XFFFAFAFA\)/);
  assert.match(tokens, /NEUTRAL900 = COLOR\(0XFF171717\)/);
  assert.match(css, /--archive-background:\s*#f8f6f1/);
  assert.match(css, /--primary-600:\s*#2563eb/);
  assert.match(css, /--primary-700:\s*#1d4ed8/);
  assert.match(css, /--neutral-50:\s*#fafafa/);
  assert.match(css, /--neutral-900:\s*#171717/);

  for (const scale of [archiveDesignTokens.primary, archiveDesignTokens.neutral]) {
    for (const hex of Object.values(scale)) {
      const bare = hex.slice(1);
      assert.match(tokens, new RegExp(bare, "i"));
      assert.match(css, new RegExp(bare, "i"));
    }
  }
  for (const [step, size] of Object.entries(archiveDesignTokens.spacing)) {
    assert.equal(size, Number(step) * 4);
    assert.match(tokens, new RegExp(`SPACING${step} = ${size}\\.0`));
    assert.match(css, new RegExp(`--spacing-${step}: ${size}px`));
  }

  const typeRoles = [
    ["headline", 32, 700],
    ["section", 22, 600],
    ["card", 18, 600],
    ["body", 16, 400],
    ["caption", 14, 400],
    ["writing", 17, 400],
  ] as const;
  for (const [role, size, weight] of typeRoles) {
    assert.equal(archiveDesignTokens.type[role].size, size);
    assert.equal(archiveDesignTokens.type[role].weight, weight);
    assert.match(css, new RegExp(`--archive-font-${role}: ${size}px`));
  }
});
