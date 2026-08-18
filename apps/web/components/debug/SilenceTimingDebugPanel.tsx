"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type { SilenceTimingDebugSnapshot } from "@/lib/refinement/silence-calibration";

function Flag({ label, active }: { label: string; active: boolean }) {
  return (
    <span
      className={
        active
          ? "rounded-full bg-emerald-500/10 px-2 py-0.5 text-[10px] text-emerald-200"
          : "rounded-full bg-white/[0.03] px-2 py-0.5 text-[10px] text-zinc-600"
      }
    >
      {label}
    </span>
  );
}

export function SilenceTimingDebugPanel({
  snapshot,
}: {
  snapshot: SilenceTimingDebugSnapshot;
}) {
  return (
    <Card className="border-white/10">
      <CardHeader className="pb-2">
        <CardTitle className="text-sm font-normal text-zinc-300">Silence timing</CardTitle>
      </CardHeader>
      <CardContent className="space-y-5">
        <div className="flex flex-wrap gap-2">
          <Flag label="Ignored cooldown" active={snapshot.ignoredCooldownActive} />
          <Flag label="High-action unlock" active={snapshot.highActionUnlockActive} />
          <Flag
            label="Related note allowance"
            active={Boolean(snapshot.relatedNoteAllowance)}
          />
          <Flag label="Weak-note suppression" active={snapshot.weakNoteSuppressed} />
        </div>

        <dl className="grid gap-3 text-xs sm:grid-cols-2">
          <div>
            <dt className="text-zinc-600">Ignored-note cooldown</dt>
            <dd className="mt-1 text-zinc-300">
              {snapshot.ignoredCooldownUntil ?? "inactive"}
            </dd>
          </div>
          <div>
            <dt className="text-zinc-600">Consecutive ignored</dt>
            <dd className="mt-1 tabular-nums text-zinc-300">
              {snapshot.consecutiveIgnored}
              {snapshot.lastTwoWithoutEngagement ? " · last 2 without action" : ""}
            </dd>
          </div>
          <div>
            <dt className="text-zinc-600">High-action unlock</dt>
            <dd className="mt-1 text-zinc-300">
              {snapshot.highActionUnlockHoursAgo !== null
                ? `${snapshot.highActionUnlockHoursAgo}h ago`
                : "none"}
            </dd>
          </div>
          <div>
            <dt className="text-zinc-600">Session notes shown</dt>
            <dd className="mt-1 tabular-nums text-zinc-300">{snapshot.sessionNoteCount}</dd>
          </div>
        </dl>

        {snapshot.relatedNoteAllowance ? (
          <div className="rounded-xl border border-white/5 px-3 py-3 text-xs">
            <p className="text-zinc-500">Related-note allowance</p>
            <p className="mt-1 text-zinc-300">
              {snapshot.relatedNoteAllowance.reason} ·{" "}
              {snapshot.relatedNoteAllowance.categories.join(", ")}
            </p>
            <p className="mt-1 text-zinc-600">
              until {snapshot.relatedNoteAllowance.expiresAt}
            </p>
          </div>
        ) : null}

        {snapshot.delayedCategories.length > 0 ? (
          <div className="rounded-xl border border-white/5 px-3 py-3 text-xs">
            <p className="text-zinc-500">Delayed categories (high dwell, no action)</p>
            <ul className="mt-2 space-y-1">
              {snapshot.delayedCategories.map((row) => (
                <li key={`${row.category}-${row.expiresAt}`} className="text-zinc-400">
                  {row.category} until {row.expiresAt}
                </li>
              ))}
            </ul>
          </div>
        ) : null}

        {snapshot.recentShown.length > 0 ? (
          <div>
            <p className="text-xs text-zinc-600">Recent shown</p>
            <ul className="mt-2 space-y-2">
              {snapshot.recentShown
                .slice()
                .reverse()
                .slice(0, 6)
                .map((row) => (
                  <li
                    key={`${row.noteId}-${row.shownAt}`}
                    className="rounded-lg border border-white/5 px-3 py-2 text-xs text-zinc-500"
                  >
                    <p className="text-zinc-300">
                      {row.noteId.slice(0, 28)}
                      {row.noteId.length > 28 ? "…" : ""}
                    </p>
                    <p className="mt-1">
                      {row.category}
                      {row.strong ? " · strong" : ""}
                      {row.actionTaken ? " · action" : ""}
                      {row.highDwellNoAction ? " · high dwell" : ""}
                    </p>
                  </li>
                ))}
            </ul>
          </div>
        ) : null}
      </CardContent>
    </Card>
  );
}
