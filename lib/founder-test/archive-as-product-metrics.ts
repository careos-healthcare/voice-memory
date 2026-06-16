import {
  ARCHIVE_AS_PRODUCT_EVENT_NAMES,
  readPostFiveFirstSurfaceCounts,
} from "@/lib/metrics/archive-as-product-events";
import { readLocalEvents } from "@/lib/local-analytics";
import {
  ARCHIVE_AS_PRODUCT_CRITERIA,
  ARCHIVE_AS_PRODUCT_MAIN_QUESTION,
  ARCHIVE_AS_PRODUCT_ROADMAP_FREEZE,
  classifyProductDescriptionVerbatim,
} from "@/lib/founder-test/archive-as-product-validation";
import { readFounderTestRecords } from "@/lib/founder-test/founder-test-storage";
import type {
  ArchiveAsProductCriterionRow,
  ArchiveAsProductValidationReport,
  ArchiveAsProductVerdict,
  ProductDescriptionCategory,
} from "@/types/archive-as-product-validation";
import type { FounderTestRecord } from "@/types/founder-test";

function pct(n: number, d: number): number | null {
  if (d <= 0) return null;
  return Math.round((n / d) * 100);
}

function criterionVerdict(
  rate: number | null,
  threshold: number,
  total: number,
): ArchiveAsProductVerdict {
  if (total < 3 && rate === null) return "insufficient_data";
  if (rate === null) return "insufficient_data";
  if (rate >= threshold) return "strong";
  if (rate < threshold / 2) return "weak";
  return "mixed";
}

function interviewArchiveLanguageRate(records: FounderTestRecord[]): number | null {
  const coded = records.filter((r) => r.session.productDescriptionCategory);
  if (coded.length === 0) return null;
  const archive = coded.filter(
    (r) => r.session.productDescriptionCategory === "archive_model",
  ).length;
  return pct(archive, coded.length);
}

function interviewPostFiveArchiveFirstRate(records: FounderTestRecord[]): number | null {
  const answered = records.filter(
    (r) => r.session.openedArchiveBeforeDiscoverPostFive !== undefined,
  );
  if (answered.length === 0) return null;
  const yes = answered.filter((r) => r.session.openedArchiveBeforeDiscoverPostFive === true)
    .length;
  return pct(yes, answered.length);
}

function interviewReflectionSixRate(records: FounderTestRecord[]): number | null {
  const answered = records.filter((r) => r.session.reflectionSixFeltStronger !== undefined);
  if (answered.length === 0) return null;
  const yes = answered.filter((r) => r.session.reflectionSixFeltStronger === true).length;
  return pct(yes, answered.length);
}

function interviewVoluntaryArchiveRate(records: FounderTestRecord[]): number | null {
  const answered = records.filter((r) => r.session.voluntaryArchiveReturn !== undefined);
  if (answered.length === 0) return null;
  const yes = answered.filter((r) => r.session.voluntaryArchiveReturn === true).length;
  return pct(yes, answered.length);
}

function devicePostFiveArchiveFirstRate(): number | null {
  const { archiveFirst, discoverFirst, total } = readPostFiveFirstSurfaceCounts();
  if (total === 0) return null;
  return pct(archiveFirst, archiveFirst + discoverFirst);
}

function deviceReflectionSixRate(): number | null {
  const fired = readLocalEvents().some(
    (e) => e.name === ARCHIVE_AS_PRODUCT_EVENT_NAMES.reflectionSixMovementSeen,
  );
  if (!fired) return null;
  return 100;
}

function deviceVoluntaryArchiveRate(): number | null {
  const fired = readLocalEvents().some(
    (e) => e.name === ARCHIVE_AS_PRODUCT_EVENT_NAMES.voluntaryArchiveReturn,
  );
  if (!fired) return null;
  return 100;
}

function overallVerdict(rows: ArchiveAsProductCriterionRow[]): ArchiveAsProductVerdict {
  const scored = rows.filter((r) => r.verdict !== "insufficient_data");
  if (scored.length === 0) return "insufficient_data";
  const strong = scored.filter((r) => r.verdict === "strong").length;
  const weak = scored.filter((r) => r.verdict === "weak").length;
  if (strong >= 3) return "strong";
  if (weak >= 2) return "weak";
  return "mixed";
}

function buildVerdictAnswer(
  verdict: ArchiveAsProductVerdict,
  rows: ArchiveAsProductCriterionRow[],
): string {
  if (verdict === "insufficient_data") {
    return "Run 10–20 founder interviews and sync device signals before deciding. Product development should stay frozen on Archive History until these move.";
  }
  if (verdict === "strong") {
    return "Archive appears to be the product in language and behaviour. Safe to build Archive History, Belief History, and Evolution replay — still no new analysis engines.";
  }
  if (verdict === "weak") {
    return "Users still treat ArchiveMe as an insight tool. Do not build Archive History yet — fix archive-first behaviour and belief movement, not missing features.";
  }
  const weakTitles = rows.filter((r) => r.verdict === "weak").map((r) => r.title);
  return `Mixed signal${weakTitles.length ? ` — weakest: ${weakTitles.join(", ")}` : ""}. Keep roadmap frozen until Archive-before-Discover and voluntary return improve.`;
}

export function buildArchiveAsProductValidationReport(
  recordsInput?: FounderTestRecord[],
): ArchiveAsProductValidationReport {
  const records = recordsInput ?? readFounderTestRecords();

  const interviewLang = interviewArchiveLanguageRate(records);
  const deviceLang = null;

  const postFiveInterview = interviewPostFiveArchiveFirstRate(records);
  const postFiveDevice = devicePostFiveArchiveFirstRate();

  const sixInterview = interviewReflectionSixRate(records);
  const sixDevice = deviceReflectionSixRate();

  const volInterview = interviewVoluntaryArchiveRate(records);
  const volDevice = deviceVoluntaryArchiveRate();

  const rates: Record<string, { interview: number | null; device: number | null }> = {
    user_language: { interview: interviewLang, device: deviceLang },
    archive_before_discover: { interview: postFiveInterview, device: postFiveDevice },
    reflection_six_value: { interview: sixInterview, device: sixDevice },
    voluntary_archive_return: { interview: volInterview, device: volDevice },
  };

  const criteria: ArchiveAsProductCriterionRow[] = ARCHIVE_AS_PRODUCT_CRITERIA.map((c) => {
    const r = rates[c.id] ?? { interview: null, device: null };
    const best =
      r.interview !== null && r.device !== null
        ? Math.round((r.interview + r.device) / 2)
        : r.interview ?? r.device;
    const verdict = criterionVerdict(best, c.passThresholdPercent, records.length);
    return {
      id: c.id,
      rank: c.rank,
      title: c.title,
      question: c.question,
      interviewRate: r.interview,
      deviceRate: r.device,
      passThresholdPercent: c.passThresholdPercent,
      verdict,
      passMeaning: c.passMeaning,
      failMeaning: c.failMeaning,
    };
  });

  const verdict = overallVerdict(criteria);

  return {
    mainQuestion: ARCHIVE_AS_PRODUCT_MAIN_QUESTION,
    verdict,
    verdictAnswer: buildVerdictAnswer(verdict, criteria),
    criteria,
    interviewCount: records.length,
    pausedBuilds: [...ARCHIVE_AS_PRODUCT_ROADMAP_FREEZE.explicitlyNot],
    buildIfValidated: [...ARCHIVE_AS_PRODUCT_ROADMAP_FREEZE.buildOnlyIfValidated],
    explicitlyNot: [...ARCHIVE_AS_PRODUCT_ROADMAP_FREEZE.explicitlyNot],
  };
}

export function suggestProductDescriptionFromQuote(
  quote: string,
): ProductDescriptionCategory {
  return classifyProductDescriptionVerbatim(quote);
}
