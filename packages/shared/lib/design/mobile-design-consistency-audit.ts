import {
  PAGE_STRUCTURE,
  type ArchiveGrammarSection,
  type ArchiveExperienceSurfaceKey,
} from "@/lib/design/archive-page-grammar";

/** Web grammar section → mobile section label(s). */
export const MOBILE_GRAMMAR_SECTION_LABELS: Record<ArchiveGrammarSection, string[]> = {
  identity: ["Archive", "Account", "Reflection Log", "Archive Activity"],
  current_state: ["Belief", "Trust"],
  change: ["Change"],
  evidence: ["Evidence", "Progress"],
  supporting_context: ["Supporting"],
  action: ["Open Archive", "Back up", "Sync"],
};

export type MobileSurfaceSpec = {
  surface: ArchiveExperienceSurfaceKey;
  dartFiles: string[];
  expectedSectionLabels: string[];
};

export const MOBILE_ARCHIVE_SURFACES: MobileSurfaceSpec[] = [
  {
    surface: "archive",
    dartFiles: ["apps/mobile/lib/screens/archive_belief_screen.dart"],
    expectedSectionLabels: ["Belief", "Trust", "Activity", "Progress", "Evidence"],
  },
  {
    surface: "changes",
    dartFiles: ["apps/mobile/lib/screens/discover_screen.dart"],
    expectedSectionLabels: ["Archive Activity"],
  },
  {
    surface: "reflection_log",
    dartFiles: ["apps/mobile/lib/screens/memory_screen.dart"],
    expectedSectionLabels: ["Reflection Log", "Memory"],
  },
  {
    surface: "account",
    dartFiles: ["apps/mobile/lib/screens/account_screen.dart"],
    expectedSectionLabels: ["Account"],
  },
];

export type MobileParityAuditResult = {
  ok: boolean;
  surface: ArchiveExperienceSurfaceKey;
  violations: string[];
  webSections: ArchiveGrammarSection[];
  mobileLabelsFound: string[];
};

export function extractMobileSectionLabels(source: string): string[] {
  const labels: string[] = [];
  const sectionLabel = source.matchAll(/_sectionLabel\(\s*['"]([^'"]+)['"]\s*\)/g);
  for (const m of sectionLabel) labels.push(m[1]);
  const templateTitles = source.matchAll(
    /ArchiveMobilePageTemplate[\s\S]*?title:\s*['"]([^'"]+)['"]/g,
  );
  for (const m of templateTitles) labels.push(m[1]);
  const headlines = source.matchAll(/Text\(\s*['"]([^'"]+)['"][\s\S]*?headlineSmall/g);
  for (const m of headlines) labels.push(m[1]);
  return labels;
}

export function auditMobileParity(
  webSections: ArchiveGrammarSection[],
  mobileSource: string,
  surface: ArchiveExperienceSurfaceKey,
): MobileParityAuditResult {
  const violations: string[] = [];
  const mobileLabelsFound = extractMobileSectionLabels(mobileSource);

  const expectedLabels = webSections.flatMap((s) => MOBILE_GRAMMAR_SECTION_LABELS[s] ?? []);
  const matched = expectedLabels.filter((label) =>
    mobileLabelsFound.some((m) => m.toLowerCase().includes(label.toLowerCase())),
  );

  if (
    surface === "archive" &&
    webSections.includes("current_state") &&
    !matched.some((m) => /belief|trust/i.test(m))
  ) {
    violations.push(`${surface}: mobile missing belief/trust hierarchy`);
  }

  if (surface === "archive" && !mobileLabelsFound.some((l) => l === "Belief")) {
    violations.push(`${surface}: mobile archive must label Belief section`);
  }

  const webOrder = webSections.map((s) => PAGE_STRUCTURE.indexOf(s));
  const mobileBeliefIdx = mobileLabelsFound.findIndex((l) => /belief/i.test(l));
  const mobileEvidenceIdx = mobileLabelsFound.findIndex((l) => /evidence/i.test(l));
  if (
    mobileBeliefIdx >= 0 &&
    mobileEvidenceIdx >= 0 &&
    mobileEvidenceIdx < mobileBeliefIdx
  ) {
    violations.push(`${surface}: mobile evidence before belief`);
  }

  return {
    ok: violations.length === 0,
    surface,
    violations,
    webSections,
    mobileLabelsFound,
  };
}
