import { readBeliefRecallRecords } from "@/lib/retention/belief-recall";
import {
  BELIEF_RECALL_STRONG_REMEMBERED_PERCENT,
  BELIEF_RECALL_WEAK_REMEMBERED_PERCENT,
} from "@/lib/retention/belief-recall-copy";
import type { BeliefRecallReport, BeliefRecallVerdict } from "@/types/belief-recall";

function rate(count: number, total: number): number | null {
  if (total === 0) return null;
  return Math.round((count / total) * 100);
}

function verdictFromRates(
  rememberedRate: number | null,
  total: number,
): BeliefRecallVerdict {
  if (total < 3) return "insufficient_data";
  if (rememberedRate === null) return "insufficient_data";
  if (rememberedRate >= BELIEF_RECALL_STRONG_REMEMBERED_PERCENT) return "strong";
  if (rememberedRate < BELIEF_RECALL_WEAK_REMEMBERED_PERCENT) return "weak";
  return "mixed";
}

export function buildBeliefRecallReport(): BeliefRecallReport {
  const records = readBeliefRecallRecords();
  const total = records.length;
  const yesClearly = records.filter((r) => r.level === "yes_clearly").length;
  const vaguely = records.filter((r) => r.level === "vaguely").length;
  const remembered = yesClearly + vaguely;

  const yesClearlyRate = rate(yesClearly, total);
  const rememberedRate = rate(remembered, total);
  const verdict = verdictFromRates(rememberedRate, total);

  let criticalAnswer =
    "Not enough belief recall responses on this device to judge whether users remember a blind spot 7 days later.";
  if (verdict === "strong") {
    criticalAnswer = `${rememberedRate}% remembered the belief (Yes or Vaguely) — users may retain what the archive surfaced.`;
  } else if (verdict === "weak") {
    criticalAnswer = `Only ${rememberedRate}% remembered the belief — recall after 7 days may still be weak.`;
  } else if (verdict !== "insufficient_data") {
    criticalAnswer = `${rememberedRate}% remembered · ${yesClearlyRate}% Yes clearly — mixed recall signal.`;
  }

  return {
    criticalQuestion: "Do users remember the belief 7 days later?",
    criticalAnswer,
    verdict,
    yesClearlyRate,
    rememberedRate,
    totalResponses: total,
    recentRecords: records.slice(0, 12),
  };
}
