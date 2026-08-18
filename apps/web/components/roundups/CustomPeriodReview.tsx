"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";

import { Button } from "@/components/ui/button";
import {
  buildPeriodFromPreset,
  formatRoundupHref,
  PERIOD_PRESET_LABELS,
  type PeriodPresetId,
} from "@/lib/roundups/reflective-roundups";
import { todayKey } from "@/lib/dates";

const PRESET_ORDER: PeriodPresetId[] = [
  "last_7_days",
  "last_30_days",
  "this_month",
  "last_month",
  "custom",
];

const DATE_INPUT_CLASS =
  "w-full rounded-xl border border-white/10 bg-zinc-900 px-3 py-2.5 text-sm text-white focus:border-violet-400/40 focus:outline-none focus:ring-2 focus:ring-violet-500/20";

export function CustomPeriodReview() {
  const router = useRouter();
  const [activePreset, setActivePreset] = useState<PeriodPresetId | null>(null);
  const [customStart, setCustomStart] = useState("");
  const [customEnd, setCustomEnd] = useState(todayKey());

  function navigateToPreset(preset: PeriodPresetId) {
    if (preset === "custom") {
      setActivePreset("custom");
      return;
    }

    const period = buildPeriodFromPreset(preset);
    if (!period) return;
    router.push(formatRoundupHref(period));
  }

  function reviewCustomPeriod() {
    const period = buildPeriodFromPreset("custom", customStart, customEnd);
    if (!period) return;
    router.push(formatRoundupHref(period));
  }

  const customReady = Boolean(customStart && customEnd);

  return (
    <section className="space-y-6 border-b border-white/[0.06] pb-14">
      <div className="space-y-2">
        <h2 className="text-xs uppercase tracking-[0.18em] text-zinc-600">Choose a period</h2>
        <p className="max-w-xl text-sm leading-relaxed text-zinc-500">
          See what changed, returned, faded, or stayed unfinished — a few lines, not a report.
        </p>
      </div>

      <div className="flex flex-wrap gap-2">
        {PRESET_ORDER.map((preset) => (
          <Button
            key={preset}
            type="button"
            variant={activePreset === preset ? "secondary" : "ghost"}
            size="sm"
            className="h-auto rounded-full px-4 py-2 text-sm text-zinc-400 hover:text-zinc-200"
            onClick={() => navigateToPreset(preset)}
          >
            {PERIOD_PRESET_LABELS[preset]}
          </Button>
        ))}
      </div>

      {activePreset === "custom" ? (
        <div className="space-y-4">
          <div className="flex flex-col gap-3 sm:flex-row">
            <label className="flex min-w-0 flex-1 flex-col gap-1.5">
              <span className="text-[10px] font-medium uppercase tracking-wider text-zinc-500">
                From
              </span>
              <input
                type="date"
                value={customStart}
                max={customEnd || todayKey()}
                onChange={(event) => setCustomStart(event.target.value)}
                className={DATE_INPUT_CLASS}
              />
            </label>
            <label className="flex min-w-0 flex-1 flex-col gap-1.5">
              <span className="text-[10px] font-medium uppercase tracking-wider text-zinc-500">
                To
              </span>
              <input
                type="date"
                value={customEnd}
                min={customStart || undefined}
                max={todayKey()}
                onChange={(event) => setCustomEnd(event.target.value)}
                className={DATE_INPUT_CLASS}
              />
            </label>
          </div>
          <Button
            type="button"
            variant="secondary"
            size="sm"
            disabled={!customReady}
            onClick={reviewCustomPeriod}
          >
            Review this period
          </Button>
        </div>
      ) : null}
    </section>
  );
}
