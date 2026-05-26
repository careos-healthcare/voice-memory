"use client";

import type { ReflectionFrictionReport } from "@/types/reflection-friction";

export function ReflectionFrictionPanel({ report }: { report: ReflectionFrictionReport }) {
  const { metrics, warnings } = report;

  return (
    <div className="space-y-8">
      <section>
        <h2 className="text-sm font-medium text-zinc-300">Metrics</h2>
        <dl className="mt-3 grid gap-3 text-sm text-zinc-400">
          <div className="flex justify-between gap-4 border-b border-white/[0.06] pb-2">
            <dt>Resurfacing seen → recorder opened</dt>
            <dd className="tabular-nums text-zinc-200">
              {metrics.resurfacingSeen} → {metrics.recorderOpenedFromReturn}
            </dd>
          </div>
          <div className="flex justify-between gap-4 border-b border-white/[0.06] pb-2">
            <dt>Recorder opened → abandoned</dt>
            <dd className="tabular-nums text-zinc-200">
              {metrics.recorderOpenedFromReturn} → {metrics.recorderAbandoned}
            </dd>
          </div>
          <div className="flex justify-between gap-4 border-b border-white/[0.06] pb-2">
            <dt>Reflection started → saved</dt>
            <dd className="tabular-nums text-zinc-200">
              {metrics.recorderOpenedFromReturn} → {metrics.reflectionSaved}
            </dd>
          </div>
          <div className="flex justify-between gap-4 border-b border-white/[0.06] pb-2">
            <dt>Avg seconds to record after callback</dt>
            <dd className="tabular-nums text-zinc-200">
              {metrics.avgSecondsToRecordAfterCallback ?? "—"}
            </dd>
          </div>
          <div className="flex justify-between gap-4 border-b border-white/[0.06] pb-2">
            <dt>Repeat dismissals</dt>
            <dd className="tabular-nums text-zinc-200">{metrics.repeatDismissals}</dd>
          </div>
          <div className="flex justify-between gap-4 border-b border-white/[0.06] pb-2">
            <dt>Surfaces before recording</dt>
            <dd className="tabular-nums text-zinc-200">
              {metrics.surfacesBeforeRecording}
            </dd>
          </div>
          <div className="flex justify-between gap-4 border-b border-white/[0.06] pb-2">
            <dt>Opened without reflection</dt>
            <dd className="tabular-nums text-zinc-200">
              {metrics.openedWithoutReflection}
            </dd>
          </div>
        </dl>
      </section>

      {warnings.length > 0 ? (
        <section>
          <h2 className="text-sm font-medium text-amber-200/90">Warnings</h2>
          <ul className="mt-3 space-y-2">
            {warnings.map((warning) => (
              <li
                key={warning.id}
                className="rounded-lg border border-amber-500/20 bg-amber-500/5 px-3 py-2 text-sm text-amber-100/90"
              >
                {warning.message}
              </li>
            ))}
          </ul>
        </section>
      ) : (
        <p className="text-sm text-zinc-500">No friction warnings from local data yet.</p>
      )}
    </div>
  );
}
