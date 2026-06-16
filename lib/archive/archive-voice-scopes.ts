import fs from "node:fs";
import path from "node:path";

import type { ArchiveVoiceScopeId } from "@/types/archive-voice";

export interface ArchiveVoiceScopeDefinition {
  id: ArchiveVoiceScopeId;
  label: string;
  dirs: string[];
  files: string[];
}

export const ARCHIVE_VOICE_SCOPES: ArchiveVoiceScopeDefinition[] = [
  {
    id: "blind_spots",
    label: "Blind Spots",
    dirs: ["lib/blind-spots", "components/blind-spots", "app/blind-spots"],
    files: [],
  },
  {
    id: "discover",
    label: "Discover",
    dirs: ["lib/discover", "components/discover", "app/discover"],
    files: ["lib/theories/personal-theory-copy.ts"],
  },
  {
    id: "theories",
    label: "Theories",
    dirs: ["components/theories", "app/theories"],
    files: [
      "lib/theories/theory-copy.ts",
      "lib/theories/personal-theory-copy.ts",
      "lib/theories/theory-confidence-movement.ts",
      "lib/archive/archive-movement-copy.ts",
      "lib/archive/continuity-reinforcement.ts",
      "lib/archive/immediate-engagement-copy.ts",
    ],
  },
  {
    id: "updates",
    label: "Updates",
    dirs: ["app/updates"],
    files: [
      "lib/theories/theory-notification-copy.ts",
      "components/theories/TheoryNotificationCard.tsx",
      "components/theories/TheoryUpdatesNav.tsx",
    ],
  },
  {
    id: "archive_value",
    label: "Archive value",
    dirs: ["components/product"],
    files: [
      "lib/product/archive-value-copy.ts",
      "lib/product/archive-value-progress.ts",
      "lib/theories/personal-theory-status.ts",
      "components/product/ArchiveValueBanner.tsx",
      "components/product/ReflectionValueLadder.tsx",
      "components/product/EvidenceBuildingCard.tsx",
      "lib/archive/archive-movement-copy.ts",
    ],
  },
];

const SOURCE_EXT = new Set([".ts", ".tsx"]);

function shouldSkipDir(name: string): boolean {
  return name === "node_modules" || name === ".next" || name.startsWith(".");
}

function collectDirFiles(root: string, relativeDir: string, out: string[]): void {
  const abs = path.join(root, relativeDir);
  if (!fs.existsSync(abs)) return;

  const entries = fs.readdirSync(abs, { withFileTypes: true });
  for (const entry of entries) {
    if (shouldSkipDir(entry.name)) continue;
    const rel = path.join(relativeDir, entry.name);
    if (entry.isDirectory()) {
      collectDirFiles(root, rel, out);
      continue;
    }
    const ext = path.extname(entry.name);
    if (!SOURCE_EXT.has(ext)) continue;
    if (/\.(test|spec)\./.test(entry.name)) continue;
    out.push(rel.replace(/\\/g, "/"));
  }
}

export function collectArchiveVoiceScopeFiles(
  root: string,
  scope: ArchiveVoiceScopeDefinition,
): string[] {
  const files = new Set<string>();
  for (const dir of scope.dirs) {
    const collected: string[] = [];
    collectDirFiles(root, dir, collected);
    for (const f of collected) files.add(f);
  }
  for (const f of scope.files) {
    if (fs.existsSync(path.join(root, f))) files.add(f);
  }
  return [...files].sort();
}

export function collectAllArchiveVoiceFiles(root: string): Map<ArchiveVoiceScopeId, string[]> {
  const map = new Map<ArchiveVoiceScopeId, string[]>();
  for (const scope of ARCHIVE_VOICE_SCOPES) {
    map.set(scope.id, collectArchiveVoiceScopeFiles(root, scope));
  }
  return map;
}
