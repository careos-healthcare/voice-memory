import fs from "node:fs";
import path from "node:path";

import {
  ARCHIVE_COPY_BANNED_PATTERNS,
  ARCHIVE_COPY_RESTRAINT,
} from "@/lib/design/archive-copy-restraint";
import { auditAllArchiveEmptyStates } from "@/lib/design/archive-empty-state-audit";
import { isApprovedArchiveIcon } from "@/lib/design/archive-icon-registry";
import {
  ARCHIVE_DECORATIVE_MOTION,
  ARCHIVE_MOTION_MAX_FADE_USES_PER_FILE,
} from "@/lib/design/archive-motion-restraint";
import { ARCHIVE_SUCCESS_BANNED } from "@/lib/design/archive-success-copy";
import { ARCHIVE_SPACE } from "@/lib/design/archive-spacing";
import { buildArchiveTasteScore, type ArchiveTasteScore } from "@/lib/design/archive-taste-score";

const ROOT = process.cwd();

function read(rel: string): string {
  return fs.readFileSync(path.join(ROOT, rel), "utf8");
}

const PUBLIC_ARCHIVE_FILES = [
  "components/archive/EvidenceArchiveHome.tsx",
  "app/discover/page.tsx",
  "app/memory/page.tsx",
  "app/account/page.tsx",
  "app/archive-detail/page.tsx",
  "lib/product/archive-product-copy.ts",
  "lib/archive/reflection-impact-receipt.ts",
  "components/archive/ArchiveEmptyState.tsx",
  "components/onboarding/ArchiveOnboarding.tsx",
];

export type ArchiveTasteFileReport = {
  score: ArchiveTasteScore;
  failures: string[];
};

export function buildArchiveTasteFileReport(): ArchiveTasteFileReport {
  const failures: string[] = [];

  let copyPass = 0;
  let copyTotal = 0;
  for (const file of PUBLIC_ARCHIVE_FILES) {
    copyTotal += 1;
    const src = read(file);
    const banned = ARCHIVE_COPY_BANNED_PATTERNS.filter((re) => re.test(src));
    const successBanned = ARCHIVE_SUCCESS_BANNED.filter((p) => src.includes(p));
    if (banned.length === 0 && successBanned.length === 0) copyPass += 1;
    else {
      failures.push(
        `${file}: copy restraint (${[...banned.map(String), ...successBanned].join(", ")})`,
      );
    }
  }

  for (const surface of Object.keys(ARCHIVE_COPY_RESTRAINT)) {
    const spec = ARCHIVE_COPY_RESTRAINT[surface as keyof typeof ARCHIVE_COPY_RESTRAINT];
    copyTotal += 1;
    if (spec.headline && spec.support.split(".").filter(Boolean).length <= 2) copyPass += 1;
    else failures.push(`copy-restraint ${surface}: support too long`);
  }

  let animPass = 0;
  let animTotal = 0;
  for (const file of [
    "components/archive/EvidenceArchiveHome.tsx",
    "components/archive/ArchiveEmptyState.tsx",
    "components/onboarding/ArchiveOnboarding.tsx",
  ]) {
    animTotal += 1;
    const src = read(file);
    const fadeUses = (src.match(/mode="fade"/g) ?? []).length;
    const cardUses = (src.match(/mode="card"/g) ?? []).length;
    const emptyUsesTransition = file.includes("ArchiveEmptyState") && src.includes("ArchiveTransition");
    if (
      fadeUses <= ARCHIVE_MOTION_MAX_FADE_USES_PER_FILE &&
      cardUses === 0 &&
      !emptyUsesTransition
    ) {
      animPass += 1;
    } else {
      failures.push(`${file}: decorative motion (fade=${fadeUses}, card=${cardUses})`);
    }
  }

  if (!read("lib/design/archive-motion-restraint.ts").includes("ARCHIVE_STATE_CHANGE_MOTION")) {
    failures.push("archive-motion-restraint missing state-change modes");
  } else {
    animPass += 1;
    animTotal += 1;
  }

  const emptyAudit = auditAllArchiveEmptyStates(read);
  const emptyPass = emptyAudit.ok ? 1 : 0;
  const emptyTotal = 1;
  if (!emptyAudit.ok) failures.push(...emptyAudit.violations);

  let ctaPass = 0;
  let ctaTotal = 0;
  for (const file of ["app/discover/page.tsx", "app/memory/page.tsx", "app/account/page.tsx"]) {
    ctaTotal += 1;
    const src = read(file);
    const primaryCount = (src.match(/primary\s*=\s*\{/g) ?? []).length;
    if (primaryCount <= 1) ctaPass += 1;
    else failures.push(`${file}: competing primary CTAs (${primaryCount})`);
  }

  let spacePass = 0;
  let spaceTotal = 0;
  const spacing = read("lib/design/archive-spacing.ts");
  spaceTotal = 2;
  if (spacing.includes("sectionBreath") || spacing.includes("space-y-10")) spacePass += 1;
  if (read("components/layout/ArchivePageBlueprint.tsx").includes("sectionBreath")) spacePass += 1;
  else failures.push("ArchivePageBlueprint must use sectionBreath spacing");

  const accountIcons = read("app/account/page.tsx");
  const iconImports = accountIcons.match(/import \{([^}]+)\} from "lucide-react"/);
  if (iconImports) {
    const names = iconImports[1].split(",").map((s) => s.trim());
    const bad = names.filter((n) => !isApprovedArchiveIcon(n));
    if (bad.length) failures.push(`account: unapproved icons ${bad.join(", ")}`);
  }

  const onboarding = read("components/onboarding/ArchiveOnboarding.tsx");
  if (!onboarding.includes("OnboardingConfidenceCheck")) {
    failures.push("ArchiveOnboarding must include OnboardingConfidenceCheck");
  }
  if (onboarding.includes("WhatIsMyArchive")) {
    failures.push("ArchiveOnboarding must not repeat WhatIsMyArchive blocks");
  }

  const score = buildArchiveTasteScore({
    copyDensity: { passed: copyPass, total: copyTotal },
    animationDensity: { passed: animPass, total: animTotal },
    emptyStateQuality: { passed: emptyPass, total: emptyTotal },
    ctaCompetition: { passed: ctaPass, total: ctaTotal },
    spacingConsistency: { passed: spacePass, total: spaceTotal },
  });

  if (!score.passesTarget) {
    failures.push(`ArchiveTasteScore ${score.total} below target ${score.target}`);
  }

  return { score, failures };
}
