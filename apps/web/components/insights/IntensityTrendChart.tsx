"use client";

import { motion } from "framer-motion";

import type { IntensityPoint } from "@/lib/journal-analytics";

interface IntensityTrendChartProps {
  points: IntensityPoint[];
}

export function IntensityTrendChart({ points }: IntensityTrendChartProps) {
  const active = points.filter((p) => p.entryCount > 0);
  const maxIntensity = 10;

  if (active.length === 0) {
    return (
      <p className="text-sm text-zinc-500">
        Intensity trend appears after a few reflections with varied emotional tone.
      </p>
    );
  }

  return (
    <div className="space-y-3">
      <div className="flex h-32 items-end gap-1 sm:gap-1.5">
        {points.map((point, index) => {
          const height =
            point.entryCount > 0
              ? Math.max(8, (point.avgIntensity / maxIntensity) * 100)
              : 4;
          const isActive = point.entryCount > 0;

          return (
            <motion.div
              key={point.dayKey}
              initial={{ opacity: 0, scaleY: 0 }}
              animate={{ opacity: 1, scaleY: 1 }}
              transition={{ delay: index * 0.02, duration: 0.3 }}
              className="group flex min-w-0 flex-1 flex-col items-center justify-end gap-1"
              title={
                isActive
                  ? `${point.label}: ${point.avgIntensity}/10 (${point.entryCount} entries)`
                  : `${point.label}: no entries`
              }
            >
              <div
                className={`w-full origin-bottom rounded-t-md transition-colors ${
                  isActive
                    ? "bg-violet-500/60 group-hover:bg-violet-400/70"
                    : "bg-white/[0.04]"
                }`}
                style={{ height: `${height}%` }}
              />
              <span className="hidden truncate text-[9px] text-zinc-600 sm:block">
                {point.label.split(",")[0]?.slice(0, 3)}
              </span>
            </motion.div>
          );
        })}
      </div>
      <p className="text-xs text-zinc-600">
        Average emotional intensity over the last 14 days (0–10 scale).
      </p>
    </div>
  );
}
