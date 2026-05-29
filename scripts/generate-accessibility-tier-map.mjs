#!/usr/bin/env node
import { writeFileSync } from "node:fs";
import { resolve } from "node:path";
import {
  EXCLUDED,
  LAUNCH_SURFACE,
  TIER_A,
  TIER_B,
  TIER_C,
  TIER_D_LOCKED,
} from "./accessibility-route-tiers-data.mjs";

const out = resolve(
  process.env.HOME ?? "/Users/chiragpatel",
  "Desktop/spp20/accessibility_route_tier_map.md",
);

const md = `# Accessibility route tier map

**Generated:** ${new Date().toISOString().slice(0, 10)}

## Tier A — launch-critical (${TIER_A.length} routes)

${TIER_A.map((r) => `- \`${r}\``).join("\n")}

## Tier B — secondary user (${TIER_B.length} routes)

${TIER_B.map((r) => `- \`${r}\``).join("\n")}

## Tier C — legal/static/support (${TIER_C.length} routes)

${TIER_C.map((r) => `- \`${r}\``).join("\n")}

## Tier D — internal locked-state only (${TIER_D_LOCKED.length} samples)

${TIER_D_LOCKED.map((r) => `- \`${r}\` → 404 without token; no founder content in body`).join("\n")}

## Excluded (${EXCLUDED.length})

${EXCLUDED.map((r) => `- \`${r}\` — dev, founder entry, or non-launch`).join("\n")}

## Strict WCAG gate

**${LAUNCH_SURFACE.length} routes** in \`LAUNCH_SURFACE_ROUTES\` (\`npm run test:a11y:full\`).

Dynamic routes (\`/entry/[id]\`, \`/threads/[slug]\`, \`/territories/[slug]\`) use representative static paths where listed in Tier B.

API routes (\`app/api/**\`) are excluded from axe; covered by \`validate:runtime-proof\` and \`validate:hostile-proof\`.
`;

writeFileSync(out, md);
console.log(`Wrote ${out}`);
