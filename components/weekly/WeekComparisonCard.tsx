import type { ReactNode } from "react";
import { ArrowDown, ArrowUp, Minus } from "lucide-react";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type { WeekComparison } from "@/lib/weekly-intelligence";

interface WeekComparisonCardProps {
  comparison: WeekComparison;
  thisWeekLabel: string;
  lastWeekLabel: string;
}

function DeltaBadge({
  current,
  previous,
  format,
}: {
  current: number | null;
  previous: number | null;
  format: (v: number) => string;
}) {
  if (current === null || previous === null) {
    return <span className="text-xs text-zinc-600">—</span>;
  }

  const delta = current - previous;
  if (Math.abs(delta) < 0.05) {
    return (
      <span className="inline-flex items-center gap-0.5 text-xs text-zinc-500">
        <Minus className="h-3 w-3" />
        flat
      </span>
    );
  }

  const up = delta > 0;
  return (
    <span
      className={`inline-flex items-center gap-0.5 text-xs ${
        up ? "text-amber-400" : "text-emerald-400"
      }`}
    >
      {up ? <ArrowUp className="h-3 w-3" /> : <ArrowDown className="h-3 w-3" />}
      {format(Math.abs(delta))}
    </span>
  );
}

function CompareRow({
  label,
  thisValue,
  lastValue,
  delta,
}: {
  label: string;
  thisValue: string;
  lastValue: string;
  delta?: ReactNode;
}) {
  return (
    <div className="grid grid-cols-[1fr_auto_1fr] items-center gap-2 text-sm">
      <div className="text-right">
        <p className="text-[10px] uppercase tracking-wider text-zinc-600">Last</p>
        <p className="mt-0.5 text-zinc-400">{lastValue}</p>
      </div>
      <div className="flex flex-col items-center px-1">
        <span className="text-[10px] font-medium uppercase tracking-wider text-violet-300/90">
          {label}
        </span>
        {delta ? <div className="mt-1">{delta}</div> : null}
      </div>
      <div>
        <p className="text-[10px] uppercase tracking-wider text-zinc-600">This</p>
        <p className="mt-0.5 font-medium text-white">{thisValue}</p>
      </div>
    </div>
  );
}

export function WeekComparisonCard({
  comparison,
  thisWeekLabel,
  lastWeekLabel,
}: WeekComparisonCardProps) {
  return (
    <Card className="border-violet-400/20 bg-gradient-to-br from-violet-500/10 via-transparent to-transparent">
      <CardHeader className="pb-2">
        <CardTitle className="text-base">This week vs last week</CardTitle>
        <p className="text-xs text-zinc-500">
          {thisWeekLabel} · vs {lastWeekLabel}
        </p>
      </CardHeader>
      <CardContent className="space-y-5">
        <CompareRow
          label="Entries"
          thisValue={String(comparison.entryCount.thisWeek)}
          lastValue={String(comparison.entryCount.lastWeek)}
          delta={
            <DeltaBadge
              current={comparison.entryCount.thisWeek}
              previous={comparison.entryCount.lastWeek}
              format={(v) => `${v}`}
            />
          }
        />
        <CompareRow
          label="Intensity"
          thisValue={
            comparison.avgIntensity.thisWeek !== null
              ? `${comparison.avgIntensity.thisWeek}/10`
              : "—"
          }
          lastValue={
            comparison.avgIntensity.lastWeek !== null
              ? `${comparison.avgIntensity.lastWeek}/10`
              : "—"
          }
          delta={
            <DeltaBadge
              current={comparison.avgIntensity.thisWeek}
              previous={comparison.avgIntensity.lastWeek}
              format={(v) => v.toFixed(1)}
            />
          }
        />
        <CompareRow
          label="Mood"
          thisValue={
            comparison.dominantEmotion.thisWeek
              ? comparison.dominantEmotion.thisWeek
              : "—"
          }
          lastValue={
            comparison.dominantEmotion.lastWeek
              ? comparison.dominantEmotion.lastWeek
              : "—"
          }
        />
        <CompareRow
          label="Theme"
          thisValue={comparison.topTheme.thisWeek ?? "—"}
          lastValue={comparison.topTheme.lastWeek ?? "—"}
        />
      </CardContent>
    </Card>
  );
}
