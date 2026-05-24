import {
  ACQUISITION_COPY_BUNDLE,
  APP_STORE_KEYWORDS,
  FULL_APP_DESCRIPTION,
  ONBOARDING_HOOKS,
  PLAY_STORE_KEYWORDS,
  SCREENSHOT_HEADLINES,
  SCREENSHOT_SETS,
  SHORT_APP_DESCRIPTION,
  TRUST_LINES,
} from "@/lib/marketing/acquisition-copy";
import {
  assessCopyLine,
  buildKeywordCoverage,
  findForbiddenAbstractPhrases,
  allScreenshotHeadlinesText,
} from "@/lib/marketing/acquisition-restraint";
import { readFirstSessionComprehensionSummary } from "@/lib/marketing/first-session-comprehension";
import type { AcquisitionReviewReport } from "@/types/acquisition-review";

function collectBannedHits(): Array<{ phrase: string; where: string }> {
  const sources: Array<[string, string]> = [
    ["shortDescription", SHORT_APP_DESCRIPTION],
    ["fullDescription", FULL_APP_DESCRIPTION],
    ["appStoreKeywords", APP_STORE_KEYWORDS],
    ...SCREENSHOT_SETS.flatMap((set) =>
      set.headlines.map((headline, index) => [
        `screenshot:${set.id}:${index + 1}`,
        headline,
      ] as [string, string]),
    ),
    ...ONBOARDING_HOOKS.map((hook, index) => [`onboarding:${index + 1}`, hook] as [string, string]),
    ...TRUST_LINES.map((line, index) => [`trust:${index + 1}`, line] as [string, string]),
  ];

  const hits: Array<{ phrase: string; where: string }> = [];
  for (const [where, text] of sources) {
    hits.push(...findForbiddenAbstractPhrases(text, where));
  }
  return hits;
}

function collectClarityIssues(rows: Array<{ text: string; source: string; normalUserWouldUnderstand: boolean; notes: string[] }>): string[] {
  const issues: string[] = [];
  for (const row of rows) {
    if (!row.normalUserWouldUnderstand) {
      issues.push(`${row.source}: ${row.text} — ${row.notes.join("; ")}`);
    }
  }
  return issues;
}

export function buildAcquisitionReviewReport(): AcquisitionReviewReport {
  const keywordCoverage = buildKeywordCoverage(
    SHORT_APP_DESCRIPTION,
    FULL_APP_DESCRIPTION,
    allScreenshotHeadlinesText(),
  );
  const coveredCount = keywordCoverage.filter((row) => row.covered).length;
  const keywordCoveragePercent =
    keywordCoverage.length > 0 ? Math.round((coveredCount / keywordCoverage.length) * 100) : 0;

  const screenshotSets = SCREENSHOT_SETS.map((set) => ({
    id: set.id,
    label: set.label,
    headlines: set.headlines,
    clarityRows: set.headlines.map((headline) => assessCopyLine(headline, `screenshot:${set.id}`)),
  }));

  const onboardingHookChecks = ONBOARDING_HOOKS.map((hook, index) =>
    assessCopyLine(hook, `onboarding:${index + 1}`),
  );
  const trustLineChecks = TRUST_LINES.map((line, index) =>
    assessCopyLine(line, `trust:${index + 1}`),
  );

  const allClarityRows = [
    assessCopyLine(SHORT_APP_DESCRIPTION, "shortDescription"),
    assessCopyLine(FULL_APP_DESCRIPTION, "fullDescription"),
    ...screenshotSets.flatMap((set) => set.clarityRows),
    ...onboardingHookChecks,
    ...trustLineChecks,
  ];

  const averageEmotionalClarityScore =
    allClarityRows.length > 0
      ? Math.round(
          allClarityRows.reduce((sum, row) => sum + row.emotionalClarityScore, 0) /
            allClarityRows.length,
        )
      : 0;

  const emotionalClarityIssues = collectClarityIssues(allClarityRows);
  const bannedAbstractHits = collectBannedHits();

  const confusionRisks = [
    ...bannedAbstractHits.map((hit) => `Banned abstract phrase "${hit.phrase}" in ${hit.where}`),
    ...emotionalClarityIssues,
  ];

  if (keywordCoveragePercent < 60) {
    confusionRisks.push(`Keyword coverage is ${keywordCoveragePercent}% — some high-intent terms missing`);
  }

  const comprehension = readFirstSessionComprehensionSummary();
  if (comprehension.confusionCount > 0) {
    confusionRisks.push(
      `${comprehension.confusionCount} first-session confusion event(s) recorded locally`,
    );
  }

  return {
    generatedAt: new Date().toISOString(),
    hasData: true,
    shortDescription: SHORT_APP_DESCRIPTION,
    fullDescription: FULL_APP_DESCRIPTION,
    appStoreKeywords: APP_STORE_KEYWORDS,
    playStoreKeywords: PLAY_STORE_KEYWORDS,
    bannedAbstractHits,
    keywordCoverage,
    keywordCoveragePercent,
    screenshotSets,
    onboardingHookChecks,
    trustLineChecks,
    averageEmotionalClarityScore,
    comprehensionSummary: comprehension,
    confusionRisks,
    emotionalClarityIssues,
  };
}

export function buildFounderAcquisitionExport(
  report: AcquisitionReviewReport = buildAcquisitionReviewReport(),
) {
  return {
    exportedAt: new Date().toISOString(),
    positioning: {
      shortDescription: report.shortDescription,
      fullDescription: report.fullDescription,
      appStoreKeywords: report.appStoreKeywords,
      playStoreKeywords: [...report.playStoreKeywords],
    },
    screenshotCopy: { ...SCREENSHOT_HEADLINES },
    asoKeywords: {
      appStore: report.appStoreKeywords,
      playStore: [...report.playStoreKeywords],
      coveragePercent: report.keywordCoveragePercent,
    },
    trustCopy: [...TRUST_LINES],
    onboardingHooks: [...ONBOARDING_HOOKS],
    confusionRisks: report.confusionRisks,
    emotionalClarityIssues: report.emotionalClarityIssues,
    firstSessionComprehension: report.comprehensionSummary,
    reviewResponseTemplates: { ...ACQUISITION_COPY_BUNDLE.reviewResponseTemplates },
  };
}

export function downloadFounderAcquisitionJson(
  report: AcquisitionReviewReport = buildAcquisitionReviewReport(),
): void {
  if (typeof window === "undefined") return;
  const payload = buildFounderAcquisitionExport(report);
  const blob = new Blob([JSON.stringify(payload, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = `voicememory-acquisition-review-${payload.exportedAt.slice(0, 10)}.json`;
  anchor.click();
  URL.revokeObjectURL(url);
}
