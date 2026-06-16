import fs from "node:fs";
import path from "node:path";

const ROOT = process.cwd();

function read(rel: string): string {
  return fs.readFileSync(path.join(ROOT, rel), "utf8");
}

function scoreFromChecks(passed: number, total: number): number {
  if (total === 0) return 100;
  return Math.round((passed / total) * 100);
}

export type ArchiveExperienceReport = {
  consistencyScore: number;
  typographyScore: number;
  spacingScore: number;
  ctaScore: number;
  hierarchyScore: number;
  languageScore: number;
  designConsistencyScore: number;
  sameProductFeel: boolean;
  notes: string[];
};

export function buildArchiveExperienceReport(): ArchiveExperienceReport {
  const notes: string[] = [];
  let typographyPass = 0;
  let typographyTotal = 0;
  let spacingPass = 0;
  let spacingTotal = 0;
  let blueprintPass = 0;
  let blueprintTotal = 0;
  let ctaPass = 0;
  let ctaTotal = 0;
  let cardPass = 0;
  let cardTotal = 0;
  let languagePass = 0;
  let languageTotal = 0;

  const blueprintPages = [
    "app/discover/page.tsx",
    "app/blind-spots/page.tsx",
    "app/updates/page.tsx",
    "app/memory/page.tsx",
    "app/account/page.tsx",
    "app/archive-detail/page.tsx",
    "components/archive/EvidenceArchiveHome.tsx",
  ];

  for (const page of blueprintPages) {
    blueprintTotal += 1;
    const src = read(page);
    if (src.includes("ArchivePageBlueprint")) blueprintPass += 1;
    else notes.push(`${page} missing ArchivePageBlueprint`);
  }

  const typoFile = read("lib/design/archive-typography.ts");
  typographyTotal = 3;
  if (typoFile.includes("pageTitle")) typographyPass += 1;
  if (typoFile.includes("ARCHIVE_TYPO")) typographyPass += 1;
  if (!read("app/discover/page.tsx").includes("text-3xl")) typographyPass += 1;

  const spacingFile = read("lib/design/archive-spacing.ts");
  spacingTotal = 2;
  if (spacingFile.includes("ARCHIVE_SPACE")) spacingPass += 1;
  for (const page of blueprintPages) {
    if (!/\bmt-\[[^\]]+\]/.test(read(page))) spacingPass += 1;
    break;
  }

  ctaTotal = 2;
  if (read("components/layout/ArchiveActionArea.tsx").includes("archive-action-area")) {
    ctaPass += 1;
  }
  if (read("app/discover/page.tsx").includes("ArchiveActionArea")) ctaPass += 1;

  cardTotal = 2;
  if (read("components/archive/ArchiveCard.tsx").includes("PRIMARY")) cardPass += 1;
  if (read("components/archive/EvidenceArchiveHome.tsx").includes("ArchiveCard")) cardPass += 1;

  const discoverCopy = read("lib/product/archive-product-copy.ts");
  const blindCopy = read("lib/blind-spots/blind-spot-copy.ts");
  languageTotal = 3;
  if (discoverCopy.includes("What changed since your last visit?")) languagePass += 1;
  if (blindCopy.includes("one reason your archive currently believes")) languagePass += 1;
  if (!read("app/blind-spots/page.tsx").includes("Pattern review")) languagePass += 1;

  const mobileTemplate = read("apps/voicememory_mobile/lib/widgets/archive_mobile_page_template.dart");
  const mobileArchive = read("apps/voicememory_mobile/lib/screens/archive_belief_screen.dart");
  let mobilePass = 0;
  if (mobileTemplate.includes("ArchiveMobilePageTemplate")) mobilePass += 1;
  if (mobileArchive.includes("ArchiveMobilePageTemplate")) mobilePass += 1;

  const typographyScore = scoreFromChecks(typographyPass, typographyTotal);
  const spacingScore = scoreFromChecks(spacingPass, spacingTotal);
  const ctaScore = scoreFromChecks(ctaPass, ctaTotal);
  const hierarchyScore = scoreFromChecks(cardPass, cardTotal);
  const languageScore = scoreFromChecks(languagePass, languageTotal);
  const consistencyScore = scoreFromChecks(
    blueprintPass + mobilePass,
    blueprintTotal + 2,
  );

  const designConsistencyScore = Math.round(
    (typographyScore +
      spacingScore +
      ctaScore +
      hierarchyScore +
      languageScore +
      consistencyScore) /
      6,
  );

  const sameProductFeel = designConsistencyScore >= 95;

  if (!sameProductFeel) {
    notes.push(
      "Target 95+ design consistency — align remaining surfaces to ArchivePageBlueprint.",
    );
  }

  return {
    consistencyScore,
    typographyScore,
    spacingScore,
    ctaScore,
    hierarchyScore,
    languageScore,
    designConsistencyScore,
    sameProductFeel,
    notes,
  };
}
