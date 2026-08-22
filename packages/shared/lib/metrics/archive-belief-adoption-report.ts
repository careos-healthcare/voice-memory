import { ARCHIVE_BELIEF_SUCCESS_CRITERIA } from "@/lib/founder-test/belief-reframing-validation";
import { readFounderTestRecords } from "@/lib/founder-test/founder-test-storage";
import { countWhyEvidenceMattersSeen } from "@/lib/metrics/evidence-education-events";
import {
  countArchiveBeliefEvent,
  ARCHIVE_BELIEF_EVENT_NAMES,
} from "@/lib/metrics/archive-belief-events";
import { readLocalEvents } from "@/lib/local-analytics";
import type { ArchiveBeliefAdoptionReport } from "@/types/archive-belief";

function pct(numerator: number, denominator: number): number | null {
  if (denominator <= 0) return null;
  return Math.round((numerator / denominator) * 1000) / 10;
}

function countDiscoverOpens(): number {
  return readLocalEvents().filter((e) => e.name === "discover_opened").length;
}

function scanProductFramingFromFounderInterviews(): {
  understanding: number;
  insights: number;
  sample: number;
} {
  const records = readFounderTestRecords();
  let understanding = 0;
  let insights = 0;
  let sample = 0;

  for (const record of records) {
    const blob = [
      record.session.mainQuote ?? "",
      record.session.biggestConfusion ?? "",
      record.session.discoverExpectationVerbatim ?? "",
    ]
      .join(" ")
      .toLowerCase();
    if (!blob.trim()) continue;
    const hasUnderstanding = /\bunderstanding\b|\bevolving model\b|\bworking theory\b/.test(
      blob,
    );
    const hasInsights = /\binsights?\b|\banswers?\b|\bcoach/.test(blob);
    if (!hasUnderstanding && !hasInsights) continue;
    sample += 1;
    if (hasUnderstanding && !hasInsights) understanding += 1;
    else if (hasInsights && !hasUnderstanding) insights += 1;
    else if (hasUnderstanding) understanding += 1;
  }

  return { understanding, insights, sample };
}

export function buildArchiveBeliefAdoptionReport(): ArchiveBeliefAdoptionReport {
  const beliefCardViewedCount = countArchiveBeliefEvent(ARCHIVE_BELIEF_EVENT_NAMES.viewed);
  const beliefExpandedCount = countArchiveBeliefEvent(ARCHIVE_BELIEF_EVENT_NAMES.expanded);
  const beliefChangeViewedCount = countArchiveBeliefEvent(
    ARCHIVE_BELIEF_EVENT_NAMES.changeViewed,
  );
  const beliefTimelineViewedCount = countArchiveBeliefEvent(
    ARCHIVE_BELIEF_EVENT_NAMES.timelineViewed,
  );
  const discoverOpenCount = countDiscoverOpens();

  const discoverOpens = Math.max(discoverOpenCount, beliefCardViewedCount, 1);
  const beliefCardOpenRate = pct(beliefCardViewedCount, discoverOpens);
  const evidenceOpenRate = pct(beliefExpandedCount, beliefCardViewedCount);
  const returnAfterBeliefChangeRate = pct(
    beliefChangeViewedCount,
    beliefCardViewedCount,
  );
  const timelineViewRate = pct(beliefTimelineViewedCount, beliefCardViewedCount);

  const framing = scanProductFramingFromFounderInterviews();
  const validationChecklist = ARCHIVE_BELIEF_SUCCESS_CRITERIA.map(
    (c) => `${c.rank}. ${c.title}: see founder interviews + device events`,
  );
  const productFramingUnderstandingPct = pct(framing.understanding, framing.sample);
  const productFramingInsightsPct = pct(framing.insights, framing.sample);

  const lines: string[] = [
    `Belief card viewed: ${beliefCardViewedCount}`,
    `Belief evidence expanded: ${beliefExpandedCount}${
      evidenceOpenRate !== null ? ` (${evidenceOpenRate}% of card views)` : ""
    }`,
    `Belief change section viewed: ${beliefChangeViewedCount}${
      returnAfterBeliefChangeRate !== null
        ? ` (${returnAfterBeliefChangeRate}% of card views)`
        : ""
    }`,
    `Founder interview framing sample: ${framing.sample} (understanding vs insights from quotes)`,
    `Belief timeline viewed: ${beliefTimelineViewedCount}`,
    `why_evidence_matters_seen: ${countWhyEvidenceMattersSeen()}`,
    `Discover opens (device): ${discoverOpenCount}`,
  ];

  if (framing.sample > 0) {
    lines.push(
      `Described as understanding: ${framing.understanding} (${productFramingUnderstandingPct ?? 0}%)`,
    );
    lines.push(
      `Described as insights: ${framing.insights} (${productFramingInsightsPct ?? 0}%)`,
    );
  }

  return {
    title: "Archive Belief Adoption",
    generatedAt: new Date().toISOString(),
    beliefCardViewedCount,
    beliefExpandedCount,
    beliefChangeViewedCount,
    beliefTimelineViewedCount,
    beliefCardOpenRate,
    evidenceOpenRate,
    returnAfterBeliefChangeRate,
    timelineViewRate,
    discoverOpenCount,
    productFramingUnderstandingPct,
    productFramingInsightsPct,
    productFramingSampleSize: framing.sample,
    validationChecklist,
    lines,
  };
}
