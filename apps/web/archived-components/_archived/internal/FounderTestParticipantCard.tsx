"use client";

import { FounderTestChecklist } from "@/archived-components/_archived/internal/FounderTestChecklist";
import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import { suggestProductDescriptionFromQuote } from "@/lib/founder-test/archive-as-product-metrics";
import { ARCHIVE_UNDERSTANDING_PROMPT } from "@/lib/founder-test/archive-understanding-validation";
import { classifyDiscoverExpectationVerbatim } from "@/lib/founder-test/founder-evolving-validation";
import type { ProductDescriptionCategory } from "@/types/archive-as-product-validation";
import type { BlindSpotReaction } from "@/types/blind-spot";
import type {
  DiscoverExpectationQuality,
  FramingAccuracyPreference,
  FounderTestRecord,
} from "@/types/founder-test";
import type { TheoryCuriosityAnswer } from "@/types/personal-theory";

const REACTION_OPTIONS: Array<{ value: "" | BlindSpotReaction; label: string }> = [
  { value: "", label: "Not recorded" },
  { value: "surprising", label: "Surprising" },
  { value: "uncomfortably_accurate", label: "Uncomfortably accurate" },
  { value: "interesting", label: "Interesting" },
  { value: "obvious", label: "Obvious" },
  { value: "completely_wrong", label: "Completely wrong" },
];

interface FounderTestParticipantCardProps {
  record: FounderTestRecord;
  onSessionChange: (
    participantId: string,
    patch: Partial<FounderTestRecord["session"]>,
  ) => void;
  onNotesChange: (participantId: string, notes: string) => void;
  onChecklistToggle: (participantId: string, itemId: string, completed: boolean) => void;
  onSyncDevice: (participantId: string) => void;
}

function triStateSelect(
  value: boolean | undefined,
  onChange: (next: boolean | undefined) => void,
  id: string,
) {
  return (
    <select
      id={id}
      value={value === undefined ? "" : value ? "yes" : "no"}
      onChange={(e) => {
        const v = e.target.value;
        onChange(v === "" ? undefined : v === "yes");
      }}
      className="w-full rounded-lg border border-white/10 bg-zinc-900 px-3 py-2 text-sm text-zinc-200"
    >
      <option value="">Not asked</option>
      <option value="yes">Yes</option>
      <option value="no">No</option>
    </select>
  );
}

export function FounderTestParticipantCard({
  record,
  onSessionChange,
  onNotesChange,
  onChecklistToggle,
  onSyncDevice,
}: FounderTestParticipantCardProps) {
  const { participant, session, checklist } = record;

  return (
    <Card className="border-white/10 bg-zinc-900/40">
      <CardHeader className="pb-2">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <CardTitle className="text-base text-zinc-100">{participant.label}</CardTitle>
            <p className="mt-1 text-xs text-zinc-500">
              Started {new Date(participant.startedAt).toLocaleDateString()} ·{" "}
              {session.reflectionCount}/{participant.targetReflectionCount} reflections
              {session.reachedFiveReflections ? " · reached 5" : ""}
            </p>
          </div>
          <button
            type="button"
            onClick={() => onSyncDevice(participant.id)}
            className="text-xs text-violet-300 underline-offset-2 hover:underline"
          >
            Sync device signals
          </button>
        </div>
      </CardHeader>
      <CardContent className="space-y-6">
        <div>
          <p className="mb-2 text-xs font-medium uppercase tracking-wide text-zinc-500">
            Checklist
          </p>
          <FounderTestChecklist
            items={checklist}
            onToggle={(itemId, completed) =>
              onChecklistToggle(participant.id, itemId, completed)
            }
          />
        </div>

        <div className="rounded-xl border border-sky-500/15 bg-sky-950/10 px-4 py-4 space-y-4">
          <p className="text-xs font-medium uppercase tracking-wide text-sky-200/90">
            Instant understanding
          </p>
          <p className="text-xs text-zinc-500">{ARCHIVE_UNDERSTANDING_PROMPT}</p>
          <label className="space-y-1 text-sm">
            <span className="text-zinc-400">Could explain in one sentence?</span>
            {triStateSelect(
              session.archiveUnderstandingCanExplain,
              (next) =>
                onSessionChange(participant.id, { archiveUnderstandingCanExplain: next }),
              `archive-understanding-${participant.id}`,
            )}
          </label>
          <label className="block space-y-1 text-sm">
            <span className="text-zinc-400">Their one-sentence explanation (verbatim)</span>
            <textarea
              value={session.archiveUnderstandingVerbatim ?? ""}
              onChange={(e) =>
                onSessionChange(participant.id, {
                  archiveUnderstandingVerbatim: e.target.value || undefined,
                })
              }
              rows={2}
              className="w-full rounded-lg border border-white/10 bg-zinc-900 px-3 py-2 text-sm text-zinc-200"
              placeholder='e.g. "My archive tracks what it believes about me"'
            />
          </label>
        </div>

        <div className="rounded-xl border border-emerald-500/15 bg-emerald-950/10 px-4 py-4 space-y-4">
          <p className="text-xs font-medium uppercase tracking-wide text-emerald-200/90">
            Archive as the product (gate before History)
          </p>
          <label className="block space-y-1 text-sm">
            <span className="text-zinc-400">How they describe ArchiveMe (verbatim)</span>
            <textarea
              value={session.productDescriptionVerbatim ?? ""}
              onChange={(e) => {
                const verbatim = e.target.value;
                const category = verbatim.trim()
                  ? suggestProductDescriptionFromQuote(verbatim)
                  : undefined;
                onSessionChange(participant.id, {
                  productDescriptionVerbatim: verbatim || undefined,
                  productDescriptionCategory: category,
                });
              }}
              rows={2}
              className="w-full rounded-lg border border-white/10 bg-zinc-900 px-3 py-2 text-sm text-zinc-200"
              placeholder='e.g. "my archive" vs "AI insights app"'
            />
          </label>
          <label className="block space-y-1 text-sm">
            <span className="text-zinc-400">Description code (override)</span>
            <select
              value={session.productDescriptionCategory ?? ""}
              onChange={(e) =>
                onSessionChange(participant.id, {
                  productDescriptionCategory: (e.target.value || undefined) as
                    | ProductDescriptionCategory
                    | undefined,
                })
              }
              className="w-full rounded-lg border border-white/10 bg-zinc-900 px-3 py-2 text-sm text-zinc-200"
            >
              <option value="">Auto / not set</option>
              <option value="archive_model">Archive model</option>
              <option value="insight_tool">Insight tool</option>
              <option value="journal_mode">Journal / reflection</option>
              <option value="mixed">Mixed</option>
              <option value="unclear">Unclear</option>
            </select>
          </label>
          <label className="space-y-1 text-sm">
            <span className="text-zinc-400">After reflection 5 — opened Archive before Discover?</span>
            {triStateSelect(
              session.openedArchiveBeforeDiscoverPostFive,
              (next) =>
                onSessionChange(participant.id, { openedArchiveBeforeDiscoverPostFive: next }),
              `archive-first-${participant.id}`,
            )}
          </label>
          <label className="space-y-1 text-sm">
            <span className="text-zinc-400">Reflection 6 — archive updated its view?</span>
            {triStateSelect(
              session.reflectionSixFeltStronger,
              (next) => onSessionChange(participant.id, { reflectionSixFeltStronger: next }),
              `reflection-six-${participant.id}`,
            )}
          </label>
          <label className="space-y-1 text-sm">
            <span className="text-zinc-400">Voluntary return to check what archive believes?</span>
            {triStateSelect(
              session.voluntaryArchiveReturn,
              (next) => onSessionChange(participant.id, { voluntaryArchiveReturn: next }),
              `voluntary-archive-${participant.id}`,
            )}
          </label>
        </div>

        <div className="rounded-xl border border-violet-500/15 bg-violet-950/10 px-4 py-4 space-y-4">
          <p className="text-xs font-medium uppercase tracking-wide text-violet-200/90">
            Evolving-understanding validation
          </p>
          <label className="block space-y-1 text-sm">
            <span className="text-zinc-400">Q1 — Which felt more accurate?</span>
            <select
              value={session.framingAccuracyPreference ?? ""}
              onChange={(e) =>
                onSessionChange(participant.id, {
                  framingAccuracyPreference: (e.target.value || undefined) as
                    | FramingAccuracyPreference
                    | undefined,
                })
              }
              className="w-full rounded-lg border border-white/10 bg-zinc-900 px-3 py-2 text-sm text-zinc-200"
            >
              <option value="">Not asked</option>
              <option value="blind_spot">Blind spot</option>
              <option value="working_theory">Working theory</option>
              <option value="no_difference">No difference</option>
            </select>
          </label>

          <label className="block space-y-1 text-sm">
            <span className="text-zinc-400">Q2 — Discover expectation (verbatim)</span>
            <textarea
              value={session.discoverExpectationVerbatim ?? ""}
              onChange={(e) => {
                const verbatim = e.target.value;
                const quality = verbatim.trim()
                  ? classifyDiscoverExpectationVerbatim(verbatim)
                  : undefined;
                onSessionChange(participant.id, {
                  discoverExpectationVerbatim: verbatim || undefined,
                  discoverExpectationQuality: quality,
                });
              }}
              rows={2}
              className="w-full rounded-lg border border-white/10 bg-zinc-900 px-3 py-2 text-sm text-zinc-200"
              placeholder="What were you expecting to see on Discover?"
            />
          </label>

          <label className="block space-y-1 text-sm">
            <span className="text-zinc-400">Q2 — Expectation quality (override)</span>
            <select
              value={session.discoverExpectationQuality ?? ""}
              onChange={(e) =>
                onSessionChange(participant.id, {
                  discoverExpectationQuality: (e.target.value || undefined) as
                    | DiscoverExpectationQuality
                    | undefined,
                })
              }
              className="w-full rounded-lg border border-white/10 bg-zinc-900 px-3 py-2 text-sm text-zinc-200"
            >
              <option value="">Auto / not set</option>
              <option value="good">Good — archive may have changed</option>
              <option value="weak">Weak — nothing / just checking</option>
              <option value="unclear">Unclear</option>
            </select>
          </label>

          <label className="block space-y-1 text-sm">
            <span className="text-zinc-400">Q3 — Curious if archive changed? (yes/maybe/no)</span>
            <select
              value={session.theoryCuriosityAnswer ?? ""}
              onChange={(e) =>
                onSessionChange(participant.id, {
                  theoryCuriosityAnswer: (e.target.value || undefined) as
                    | TheoryCuriosityAnswer
                    | undefined,
                })
              }
              className="w-full rounded-lg border border-white/10 bg-zinc-900 px-3 py-2 text-sm text-zinc-200"
            >
              <option value="">Not asked</option>
              <option value="yes">Yes</option>
              <option value="maybe">Maybe</option>
              <option value="no">No</option>
            </select>
          </label>

          <label className="space-y-1 text-sm">
            <span className="text-zinc-400">Q4 — Returned ≥24h to check archive view?</span>
            {triStateSelect(
              session.returnedToCheckArchiveView,
              (next) => onSessionChange(participant.id, { returnedToCheckArchiveView: next }),
              `return-check-${participant.id}`,
            )}
          </label>
        </div>

        <div className="grid gap-4 sm:grid-cols-2">
          <label className="space-y-1 text-sm">
            <span className="text-zinc-400">First blind spot reaction</span>
            <select
              value={session.firstBlindSpotReaction ?? ""}
              onChange={(e) =>
                onSessionChange(participant.id, {
                  firstBlindSpotReaction: (e.target.value || undefined) as
                    | BlindSpotReaction
                    | undefined,
                })
              }
              className="w-full rounded-lg border border-white/10 bg-zinc-900 px-3 py-2 text-sm text-zinc-200"
            >
              {REACTION_OPTIONS.map((opt) => (
                <option key={opt.label} value={opt.value}>
                  {opt.label}
                </option>
              ))}
            </select>
          </label>

          <label className="space-y-1 text-sm">
            <span className="text-zinc-400">Understood ChatGPT difference?</span>
            {triStateSelect(
              session.understoodChatGptDifference,
              (next) => onSessionChange(participant.id, { understoodChatGptDifference: next }),
              `chatgpt-${participant.id}`,
            )}
          </label>

          <label className="space-y-1 text-sm">
            <span className="text-zinc-400">Returned within 7 days?</span>
            {triStateSelect(
              session.returnedWithin7Days,
              (next) => onSessionChange(participant.id, { returnedWithin7Days: next }),
              `return-${participant.id}`,
            )}
          </label>

          <label className="space-y-1 text-sm">
            <span className="text-zinc-400">Would pay?</span>
            {triStateSelect(
              session.wouldPay,
              (next) => onSessionChange(participant.id, { wouldPay: next }),
              `pay-${participant.id}`,
            )}
          </label>
        </div>

        <label className="block space-y-1 text-sm">
          <span className="text-zinc-400">Main quote</span>
          <textarea
            value={session.mainQuote ?? ""}
            onChange={(e) =>
              onSessionChange(participant.id, { mainQuote: e.target.value || undefined })
            }
            rows={2}
            className="w-full rounded-lg border border-white/10 bg-zinc-900 px-3 py-2 text-sm text-zinc-200"
            placeholder="Verbatim line that stuck"
          />
        </label>

        <label className="block space-y-1 text-sm">
          <span className="text-zinc-400">Biggest confusion</span>
          <textarea
            value={session.biggestConfusion ?? ""}
            onChange={(e) =>
              onSessionChange(participant.id, {
                biggestConfusion: e.target.value || undefined,
              })
            }
            rows={2}
            className="w-full rounded-lg border border-white/10 bg-zinc-900 px-3 py-2 text-sm text-zinc-200"
            placeholder='e.g. "Why not just use ChatGPT?"'
          />
        </label>

        <label className="block space-y-1 text-sm">
          <span className="text-zinc-400">Founder notes</span>
          <textarea
            value={participant.notes ?? ""}
            onChange={(e) => onNotesChange(participant.id, e.target.value)}
            rows={2}
            className="w-full rounded-lg border border-white/10 bg-zinc-900 px-3 py-2 text-sm text-zinc-200"
          />
        </label>

        <div className="flex flex-wrap gap-3 text-xs text-zinc-500">
          <span>Blind spots: {session.openedBlindSpots ? "opened" : "not yet"}</span>
          <span>Discover: {session.openedDiscover ? "opened" : "not yet"}</span>
        </div>
      </CardContent>
    </Card>
  );
}
