import { beliefSurvivedChallengesLine } from "@/lib/archive/belief-survival";
import { buildBeliefSurvivalView } from "@/lib/archive/belief-survival";
import { buildArchiveBeliefView } from "@/lib/archive/archive-belief";
import { buildTheoryTrackerReport } from "@/lib/theories/theory-generation";
import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import {
  distributionMomentsForShare,
  latestDistributionMoment,
} from "@/lib/distribution/transformation-moments";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type {
  ArchiveShareCardModel,
  ArchiveShareCardVariant,
  TransformationMomentType,
} from "@/types/distribution";
import type { JournalEntry } from "@/types/journal";

const VARIANT_LINES: Record<ArchiveShareCardVariant, (ctx: ShareCardContext) => string> = {
  belief_changed_mind: () => "My archive changed its mind.",
  pattern_tracked_days: (ctx) =>
    `My archive has tracked this pattern for ${ctx.daysTracked} days.`,
  no_longer_believes: () => "My archive no longer believes this.",
  survived_challenges: (ctx) =>
    beliefSurvivedChallengesLine(ctx.challengesSurvived),
};

type ShareCardContext = {
  daysTracked: number;
  challengesSurvived: number;
};

function eligible(entries: JournalEntry[]): JournalEntry[] {
  return entries.filter((e) => e.reflectionPending !== true);
}

function archiveAgeDays(entries: JournalEntry[]): number {
  const list = eligible(entries);
  if (list.length === 0) return 0;
  const sorted = [...list].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
  const first = toDayKey(sorted[0]!.createdAt);
  const last = toDayKey(sorted[list.length - 1]!.createdAt);
  return Math.max(1, daysBetweenKeys(first, last) + 1);
}

function momentToVariant(type: TransformationMomentType): ArchiveShareCardVariant | null {
  switch (type) {
    case "belief_change":
    case "archive_changed_while_away":
    case "first_return_after_archive_change":
      return "belief_changed_mind";
    case "first_belief":
    case "first_strong_attachment":
      return "pattern_tracked_days";
    case "belief_challenged":
      return "no_longer_believes";
    case "first_contradiction":
      return "survived_challenges";
    default:
      return null;
  }
}

function buildContext(entries: JournalEntry[]): ShareCardContext {
  const survival = buildBeliefSurvivalView(entries);
  return {
    daysTracked: survival?.daysAlive ?? archiveAgeDays(entries),
    challengesSurvived: survival?.contradictionsSurvived ?? 0,
  };
}

function cardFromVariant(
  variant: ArchiveShareCardVariant,
  ctx: ShareCardContext,
  momentType?: TransformationMomentType,
): ArchiveShareCardModel {
  return {
    id: `share-${variant}-${momentType ?? "default"}`,
    variant,
    line: VARIANT_LINES[variant](ctx),
    subline: "ArchiveMe",
    momentType,
  };
}

/** Build screenshot-safe share cards — no private reflection text. */
export function buildArchiveShareCards(
  entriesInput?: JournalEntry[],
): ArchiveShareCardModel[] {
  const entries = eligible(entriesInput ?? getMemoryEligibleEntries());
  const ctx = buildContext(entries);
  const cards: ArchiveShareCardModel[] = [];
  const seen = new Set<ArchiveShareCardVariant>();

  for (const moment of distributionMomentsForShare()) {
    const variant = momentToVariant(moment.type);
    if (!variant || seen.has(variant)) continue;
    seen.add(variant);
    cards.push(cardFromVariant(variant, ctx, moment.type));
  }

  const belief = buildArchiveBeliefView(entries);
  const report = buildTheoryTrackerReport(entries, { persistSnapshots: false });
  const lead = belief
    ? report.all.find((t) => t.id === belief.theoryId)
    : report.all[0];

  if (!seen.has("belief_changed_mind") && lead && lead.whatChanged.length > 0) {
    cards.push(cardFromVariant("belief_changed_mind", ctx, "belief_change"));
    seen.add("belief_changed_mind");
  }

  if (!seen.has("pattern_tracked_days") && ctx.daysTracked >= 7) {
    cards.push(cardFromVariant("pattern_tracked_days", ctx, "first_belief"));
    seen.add("pattern_tracked_days");
  }

  if (!seen.has("survived_challenges") && ctx.challengesSurvived >= 1) {
    cards.push(cardFromVariant("survived_challenges", ctx, "first_contradiction"));
    seen.add("survived_challenges");
  }

  if (cards.length === 0) {
    const latest = latestDistributionMoment();
    const variant = latest ? momentToVariant(latest.type) : "pattern_tracked_days";
    cards.push(
      cardFromVariant(variant ?? "pattern_tracked_days", ctx, latest?.type),
    );
  }

  return cards.slice(0, 4);
}

export function pickPrimaryArchiveShareCard(
  entriesInput?: JournalEntry[],
): ArchiveShareCardModel | null {
  return buildArchiveShareCards(entriesInput)[0] ?? null;
}
