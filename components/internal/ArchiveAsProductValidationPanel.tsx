"use client";

import { useMemo } from "react";

import {
  ARCHIVE_AS_PRODUCT_CRITERIA,
  ARCHIVE_AS_PRODUCT_INTERVIEW_QUESTIONS,
  ARCHIVE_AS_PRODUCT_ROADMAP_FREEZE,
} from "@/lib/founder-test/archive-as-product-validation";
import { ARCHIVE_AS_PRODUCT_EVENT_NAMES } from "@/lib/metrics/archive-as-product-events";
import { readPostFiveFirstSurfaceCounts } from "@/lib/metrics/archive-as-product-events";
import { readLocalEvents } from "@/lib/local-analytics";
import { buildArchiveAsProductValidationReport } from "@/lib/founder-test/archive-as-product-metrics";
import { readFounderTestRecords } from "@/lib/founder-test/founder-test-storage";
import type { ArchiveAsProductValidationReport } from "@/types/archive-as-product-validation";

interface ArchiveAsProductValidationPanelProps {
  report?: ArchiveAsProductValidationReport;
}

function formatRate(rate: number | null): string {
  if (rate === null) return "—";
  return `${rate}%`;
}

function verdictColor(verdict: string): string {
  if (verdict === "strong") return "text-emerald-400";
  if (verdict === "weak") return "text-amber-400";
  if (verdict === "mixed") return "text-violet-300";
  return "text-zinc-500";
}

export function ArchiveAsProductValidationPanel({
  report: reportProp,
}: ArchiveAsProductValidationPanelProps) {
  const records = useMemo(() => readFounderTestRecords(), []);
  const report = useMemo(
    () => reportProp ?? buildArchiveAsProductValidationReport(records),
    [reportProp, records],
  );
  const events = readLocalEvents();
  const postFive = readPostFiveFirstSurfaceCounts();
  const archiveHomeOpens = events.filter(
    (e) => e.name === ARCHIVE_AS_PRODUCT_EVENT_NAMES.archiveHomeOpened,
  ).length;
  const reflectionSix = events.filter(
    (e) => e.name === ARCHIVE_AS_PRODUCT_EVENT_NAMES.reflectionSixMovementSeen,
  ).length;
  const voluntary = events.filter(
    (e) => e.name === ARCHIVE_AS_PRODUCT_EVENT_NAMES.voluntaryArchiveReturn,
  ).length;

  return (
    <section className="space-y-6 rounded-2xl border border-violet-500/25 bg-violet-950/10 p-6">
      <div>
        <p className="text-xs uppercase tracking-[0.18em] text-violet-300/80">
          Archive as the product
        </p>
        <h2 className="mt-2 text-lg font-semibold text-white">{report.mainQuestion}</h2>
        <p className={`mt-3 text-sm leading-relaxed ${verdictColor(report.verdict)}`}>
          {report.verdictAnswer}
        </p>
        <p className="mt-2 text-xs text-zinc-500">
          Interviews recorded: {report.interviewCount} · Verdict: {report.verdict}
        </p>
      </div>

      <ol className="space-y-5">
        {report.criteria.map((row) => {
          const def = ARCHIVE_AS_PRODUCT_CRITERIA.find((c) => c.id === row.id);
          return (
            <li
              key={row.id}
              className="rounded-xl border border-white/10 bg-zinc-900/40 px-4 py-4"
            >
              <p className="text-sm font-medium text-zinc-200">
                {row.rank}. {row.title}
              </p>
              <p className="mt-1 text-xs text-zinc-500">{row.question}</p>
              <dl className="mt-3 grid gap-2 text-xs sm:grid-cols-3">
                <div>
                  <dt className="text-zinc-600">Interview</dt>
                  <dd className="text-zinc-300">{formatRate(row.interviewRate)}</dd>
                </div>
                <div>
                  <dt className="text-zinc-600">Device</dt>
                  <dd className="text-zinc-300">{formatRate(row.deviceRate)}</dd>
                </div>
                <div>
                  <dt className="text-zinc-600">Pass ≥</dt>
                  <dd className="text-zinc-300">{row.passThresholdPercent}%</dd>
                </div>
              </dl>
              <p className={`mt-2 text-xs ${verdictColor(row.verdict)}`}>
                {row.verdict === "strong" ? row.passMeaning : row.failMeaning}
              </p>
              {def && "passSignals" in def ? (
                <ul className="mt-2 list-disc pl-4 text-xs text-zinc-600">
                  {def.passSignals.map((s) => (
                    <li key={s}>{s}</li>
                  ))}
                </ul>
              ) : null}
            </li>
          );
        })}
      </ol>

      <div className="rounded-xl border border-dashed border-white/10 px-4 py-4">
        <p className="text-xs uppercase tracking-wider text-zinc-500">This browser (device)</p>
        <dl className="mt-3 grid gap-3 text-sm sm:grid-cols-2">
          <div>
            <dt className="text-zinc-600">Archive home opens</dt>
            <dd className="text-zinc-200">{archiveHomeOpens}</dd>
          </div>
          <div>
            <dt className="text-zinc-600">Post-5 first: Archive / Discover</dt>
            <dd className="text-zinc-200">
              {postFive.archiveFirst} / {postFive.discoverFirst} ({postFive.total} tracked)
            </dd>
          </div>
          <div>
            <dt className="text-zinc-600">Reflection 6 movement seen</dt>
            <dd className="text-zinc-200">{reflectionSix}</dd>
          </div>
          <div>
            <dt className="text-zinc-600">Voluntary archive return</dt>
            <dd className="text-zinc-200">{voluntary}</dd>
          </div>
        </dl>
      </div>

      <div className="rounded-xl border border-amber-500/20 bg-amber-950/10 px-4 py-4">
        <p className="text-xs uppercase tracking-wider text-amber-200/80">Roadmap gate</p>
        <p className="mt-2 text-sm text-zinc-300">{ARCHIVE_AS_PRODUCT_ROADMAP_FREEZE.hypothesis}</p>
        <p className="mt-3 text-xs font-medium text-zinc-500">Build only if validated</p>
        <p className="text-xs text-zinc-600">{report.buildIfValidated.join(" · ")}</p>
        <p className="mt-3 text-xs font-medium text-zinc-500">Explicitly not</p>
        <p className="text-xs text-zinc-600">{report.explicitlyNot.join(" · ")}</p>
      </div>

      <div className="rounded-xl border border-white/10 px-4 py-4">
        <p className="text-xs uppercase tracking-wider text-zinc-500">Founder interview script</p>
        <ol className="mt-3 list-decimal space-y-2 pl-5 text-sm text-zinc-400">
          {ARCHIVE_AS_PRODUCT_INTERVIEW_QUESTIONS.map((q) => (
            <li key={q}>{q}</li>
          ))}
        </ol>
      </div>
    </section>
  );
}
