import {
  analyzeWeeklyIntelligence,
  type WeeklyIntelligenceReport,
} from "@/lib/weekly-intelligence";
import type { InsightShareCardModel } from "@/types/insight-share";

import { buildInsightShareReferralLink, INSIGHT_SHARE_REFERRAL_SOURCE } from "./insight-share-referral";
import { sanitizeInsightShareLines, stripInsightSharePii } from "./insight-share-pii";

const HEADLINE = "Your week in reflection";
const FOOTER = "ArchiveMe";

function sanitizeLabel(label: string | null | undefined): string | null {
  if (!label) return null;
  const cleaned = stripInsightSharePii(label);
  return cleaned || null;
}

function buildPatternLines(report: WeeklyIntelligenceReport): string[] {
  const { thisWeek, comparison, emotionalShift } = report;
  const lines: string[] = [];

  lines.push(
    `${thisWeek.entryCount} reflection${thisWeek.entryCount === 1 ? "" : "s"} this week`,
  );

  const mood = sanitizeLabel(thisWeek.dominantEmotions[0]?.label);
  if (mood) {
    lines.push(`Dominant tone: ${mood}`);
  }

  const theme = sanitizeLabel(thisWeek.recurringThemes[0]?.label);
  if (theme) {
    const count = thisWeek.recurringThemes[0]?.count ?? 0;
    lines.push(
      count > 1
        ? `Theme returning: ${theme} (${count} mentions)`
        : `Theme returning: ${theme}`,
    );
  }

  const shift = sanitizeLabel(emotionalShift.label);
  if (shift) {
    lines.push(shift);
  }

  const lastWeekTheme = sanitizeLabel(comparison.topTheme.lastWeek);
  const thisWeekTheme = sanitizeLabel(comparison.topTheme.thisWeek);
  if (thisWeekTheme && lastWeekTheme && thisWeekTheme === lastWeekTheme) {
    lines.push(`"${thisWeekTheme}" stayed on your mind two weeks running`);
  }

  const diff = thisWeek.entryCount - comparison.entryCount.lastWeek;
  if (comparison.entryCount.lastWeek > 0 && diff > 0) {
    lines.push(`${diff} more check-in${diff === 1 ? "" : "s"} than last week`);
  }

  return sanitizeInsightShareLines(lines);
}

function buildPlainText(model: Omit<InsightShareCardModel, "plainTextShare">): string {
  return [
    model.headline,
    model.weekRangeLabel,
    ...model.patternLines,
    "",
    model.footer,
  ].join("\n");
}

/** Builds a privacy-safe weekly pattern card from aggregate stats only. */
export function buildInsightShareCard(
  reportInput?: WeeklyIntelligenceReport,
): InsightShareCardModel | null {
  const report = reportInput ?? analyzeWeeklyIntelligence();
  if (!report.hasData) return null;

  const patternLines = buildPatternLines(report);
  if (patternLines.length === 0) return null;

  const referralLink = buildInsightShareReferralLink();
  const base = {
    id: `weekly-insight-${report.weekEndingKey}`,
    weekRangeLabel: stripInsightSharePii(report.weekRangeLabel),
    headline: HEADLINE,
    patternLines,
    footer: FOOTER,
    referralLink,
    referralSource: INSIGHT_SHARE_REFERRAL_SOURCE,
  };

  return {
    ...base,
    plainTextShare: buildPlainText(base),
  };
}
