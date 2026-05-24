import { sortByEmotionalSurvival } from "@/lib/debug/callback-quality-score";
import type { CallbackQualityReviewReport, CallbackReviewItem } from "@/types/callback-quality-review";
import type {
  CallbackPruningAction,
  CallbackPruningExport,
  CallbackPruningExportItem,
  StoredCallbackPruningDecision,
} from "@/types/observation-workflow";

const PRUNING_KEY = "voicememory_callback_pruning";

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function readDecisionsRaw(): StoredCallbackPruningDecision[] {
  if (!isBrowser()) return [];
  try {
    const raw = localStorage.getItem(PRUNING_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as StoredCallbackPruningDecision[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function writeDecisionsRaw(decisions: StoredCallbackPruningDecision[]): void {
  if (!isBrowser()) return;
  localStorage.setItem(PRUNING_KEY, JSON.stringify(decisions.slice(-500)));
}

export function getCallbackPruningAction(callbackId: string): CallbackPruningAction | null {
  return readDecisionsRaw().find((row) => row.callbackId === callbackId)?.action ?? null;
}

export function setCallbackPruningAction(
  callbackId: string,
  action: CallbackPruningAction,
  noteText: string,
): CallbackPruningAction {
  const decisions = readDecisionsRaw().filter((row) => row.callbackId !== callbackId);
  decisions.push({
    callbackId,
    action,
    noteText: noteText.slice(0, 280),
    updatedAt: new Date().toISOString(),
  });
  writeDecisionsRaw(decisions);
  return action;
}

export function clearCallbackPruningDecisions(): void {
  if (!isBrowser()) return;
  localStorage.removeItem(PRUNING_KEY);
}

export function readAllCallbackPruningDecisions(): StoredCallbackPruningDecision[] {
  return readDecisionsRaw().sort(
    (a, b) => new Date(b.updatedAt).getTime() - new Date(a.updatedAt).getTime(),
  );
}

function recommendAction(item: CallbackReviewItem): CallbackPruningAction {
  if (item.doubleDown || item.emotionalResidueScore >= 58) return "double_down";
  if (item.cutCandidate || item.survival.emotionalSurvivalScore < 22) return "cut";
  if (item.rewriteFlags.length >= 2 || item.manualLabels.includes("too_analytical")) return "rewrite";
  return "keep";
}

function toExportItem(
  item: CallbackReviewItem,
  category: CallbackPruningExportItem["category"],
  manualAction?: CallbackPruningAction,
): CallbackPruningExportItem {
  return {
    id: item.id,
    kind: item.kind,
    text: item.text,
    emotionalResidueScore: item.emotionalResidueScore,
    survivalScore: item.survival.emotionalSurvivalScore,
    category,
    recommendedAction: recommendAction(item),
    manualAction,
  };
}

export function buildCallbackPruningExport(
  report: CallbackQualityReviewReport,
): CallbackPruningExport {
  const decisions = readAllCallbackPruningDecisions();
  const decisionMap = new Map(decisions.map((row) => [row.callbackId, row.action]));

  const weakCallbacks = report.items
    .filter((item) => item.cutCandidate || item.qualityScore < 42)
    .map((item) => toExportItem(item, "weak", decisionMap.get(item.id)));

  const lowSurvivalCallbacks = report.items
    .filter((item) => item.survival.emotionalSurvivalScore < 28)
    .map((item) => toExportItem(item, "low_survival", decisionMap.get(item.id)));

  const genericCallbacks = report.items
    .filter(
      (item) =>
        item.manualLabels.includes("felt_generic") ||
        item.rewriteFlags.includes("generic_wording") ||
        item.rewriteFlags.includes("could_apply_to_many"),
    )
    .map((item) => toExportItem(item, "generic", decisionMap.get(item.id)));

  const highResidueCallbacks = sortByEmotionalSurvival(report.items)
    .filter((item) => item.emotionalResidueScore >= 55 || item.doubleDown)
    .slice(0, 24)
    .map((item) => toExportItem(item, "high_residue", decisionMap.get(item.id)));

  return {
    exportedAt: new Date().toISOString(),
    callbackCount: report.items.length,
    weakCallbacks,
    lowSurvivalCallbacks,
    genericCallbacks,
    highResidueCallbacks,
    decisions,
  };
}

export function downloadCallbackPruningJson(report: CallbackQualityReviewReport): void {
  if (!isBrowser()) return;

  const payload = buildCallbackPruningExport(report);
  const blob = new Blob([JSON.stringify(payload, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = `callback-pruning-${payload.exportedAt.slice(0, 10)}.json`;
  anchor.click();
  URL.revokeObjectURL(url);
}

export const PRUNING_ACTION_LABELS: Record<CallbackPruningAction, string> = {
  cut: "Cut",
  rewrite: "Rewrite",
  keep: "Keep",
  double_down: "Double down",
};
