import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type {
  DayEntryPoint,
  DayIntensityPoint,
  RankedItem,
} from "@/lib/weekly-intelligence";

export function IntensityWeekChart({ points }: { points: DayIntensityPoint[] }) {
  const maxIntensity = Math.max(
    10,
    ...points.filter((p) => p.entryCount > 0).map((p) => p.avgIntensity),
    1,
  );

  return (
    <div className="flex items-end gap-1.5 overflow-x-auto pb-1 pt-2">
      {points.map((point) => {
        const height =
          point.entryCount > 0
            ? Math.max(10, (point.avgIntensity / maxIntensity) * 100)
            : 6;

        return (
          <div
            key={point.dayKey}
            className="flex min-w-[2.25rem] flex-1 flex-col items-center gap-1.5"
            title={
              point.entryCount
                ? `${point.label}: ${point.avgIntensity}/10`
                : point.label
            }
          >
            <div className="flex h-28 w-full items-end justify-center sm:h-32">
              <div
                className={`w-full max-w-5 rounded-t-md transition-all ${
                  point.entryCount > 0
                    ? "bg-gradient-to-t from-violet-600 to-fuchsia-400"
                    : "bg-white/10"
                }`}
                style={{ height: `${height}%` }}
              />
            </div>
            <span className="text-[10px] font-medium text-zinc-500">
              {point.shortLabel}
            </span>
          </div>
        );
      })}
    </div>
  );
}

export function EntryTimelineChart({ points }: { points: DayEntryPoint[] }) {
  const maxCount = Math.max(1, ...points.map((p) => p.count));

  return (
    <div className="relative mt-2">
      <div className="absolute left-2 right-2 top-1/2 h-px -translate-y-1/2 bg-white/10" />
      <div className="flex justify-between gap-1 px-1">
        {points.map((point) => {
          const size =
            point.count > 0
              ? Math.max(10, Math.round((point.count / maxCount) * 22))
              : 8;

          return (
            <div
              key={point.dayKey}
              className="flex flex-1 flex-col items-center gap-2"
            >
              <div
                className={`relative z-10 rounded-full ${
                  point.count > 0
                    ? "bg-violet-500 ring-2 ring-violet-400/30"
                    : "bg-zinc-800 ring-1 ring-white/10"
                }`}
                style={{ width: size, height: size }}
                title={`${point.label}: ${point.count} entries`}
              />
              <span className="text-[10px] text-zinc-600">{point.shortLabel}</span>
            </div>
          );
        })}
      </div>
    </div>
  );
}

export function RankedListCard({
  title,
  subtitle,
  items,
  emptyLabel,
  capitalize = false,
}: {
  title: string;
  subtitle?: string;
  items: RankedItem[];
  emptyLabel: string;
  capitalize?: boolean;
}) {
  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="text-base">{title}</CardTitle>
        {subtitle ? <p className="text-xs text-zinc-500">{subtitle}</p> : null}
      </CardHeader>
      <CardContent>
        {items.length === 0 ? (
          <p className="text-sm text-zinc-500">{emptyLabel}</p>
        ) : (
          <ul className="space-y-2.5">
            {items.map((item, index) => {
              const max = items[0]?.count ?? 1;
              const width = Math.max(12, (item.count / max) * 100);

              return (
                <li key={`${item.label}-${index}`}>
                  <div className="flex items-center justify-between gap-2 text-sm">
                    <span
                      className={`truncate text-zinc-200 ${capitalize ? "capitalize" : ""}`}
                    >
                      {item.label}
                    </span>
                    <span className="shrink-0 tabular-nums text-xs text-violet-300">
                      {item.count}×
                    </span>
                  </div>
                  <div className="mt-1.5 h-1.5 overflow-hidden rounded-full bg-white/10">
                    <div
                      className="h-full rounded-full bg-gradient-to-r from-violet-600 to-fuchsia-400"
                      style={{ width: `${width}%` }}
                    />
                  </div>
                </li>
              );
            })}
          </ul>
        )}
      </CardContent>
    </Card>
  );
}

export function TrendStatCard({
  label,
  value,
  hint,
}: {
  label: string;
  value: string;
  hint?: string;
}) {
  return (
    <Card className="min-w-0 flex-1">
      <CardContent className="p-4">
        <p className="text-[10px] font-medium uppercase tracking-wider text-zinc-500">
          {label}
        </p>
        <p className="mt-1 truncate text-2xl font-semibold tabular-nums text-white">
          {value}
        </p>
        {hint ? <p className="mt-1 text-xs text-zinc-500">{hint}</p> : null}
      </CardContent>
    </Card>
  );
}
