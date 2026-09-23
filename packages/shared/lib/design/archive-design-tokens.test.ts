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
});
