"use client";

import { Download } from "lucide-react";
import Link from "next/link";

import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { downloadValidationOpsJson, rolloutStageLabel } from "@/lib/debug/validation-ops-review";
import type { ValidationOpsReport } from "@/types/validation-ops";

function MetricTable({
  title,
  rows,
}: {
  title: string;
  rows: Array<{ id: string; label: string; value: string; detail?: string }>;
}) {
  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="text-sm font-normal text-zinc-200">{title}</CardTitle>
      </CardHeader>
      <CardContent>
        <table className="w-full text-sm">
          <tbody>
            {rows.map((row) => (
              <tr key={row.id} className="border-t border-white/[0.04] first:border-t-0">
                <td className="py-2 pr-4 text-zinc-500">{row.label}</td>
                <td className="py-2 pr-4 tabular-nums text-zinc-200">{row.value}</td>
                <td className="py-2 text-xs text-zinc-600">{row.detail ?? ""}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </CardContent>
    </Card>
  );
}

function RankedList({
  title,
  rows,
  empty,
}: {
  title: string;
  rows: Array<{ id: string; label: string; detail?: string }>;
  empty: string;
}) {
  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="text-sm font-normal text-zinc-200">{title}</CardTitle>
      </CardHeader>
      <CardContent>
        {rows.length === 0 ? (
          <p className="text-sm text-zinc-500">{empty}</p>
        ) : (
          <ul className="space-y-2 text-sm text-zinc-400">
            {rows.map((row) => (
              <li key={row.id}>
                {row.label}
                {row.detail ? <span className="text-zinc-600"> — {row.detail}</span> : null}
              </li>
            ))}
          </ul>
        )}
      </CardContent>
    </Card>
  );
}

export function ValidationOpsPanel({ report }: { report: ValidationOpsReport }) {
  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <p className="text-sm text-zinc-500">
          Controlled rollout observation — retention, attachment, trust, and willingness. Not a growth dashboard.
        </p>
        <Button type="button" variant="secondary" size="sm" onClick={() => downloadValidationOpsJson(report)}>
          <Download className="h-4 w-4" />
          Export JSON
        </Button>
      </div>

      {report.rollout.observeMessage ? (
        <Card className="border-amber-900/30">
          <CardContent className="py-4 text-sm text-amber-200/90">{report.rollout.observeMessage}</CardContent>
        </Card>
      ) : null}

      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardHeader className="pb-1">
            <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">Active testers</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold tabular-nums text-white">{report.activeTesters.length}</p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-1">
            <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">Rollout stage</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-lg font-semibold text-white">{rolloutStageLabel(report.rollout.recommendedStage)}</p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-1">
            <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">Attachment</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold tabular-nums text-white">{report.attachment.attachmentScore}</p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-1">
            <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">Warnings</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold tabular-nums text-white">{report.warnings.warnings.length}</p>
          </CardContent>
        </Card>
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <MetricTable
          title="Retention"
          rows={[report.retention.d1, report.retention.d7, report.retention.d30]}
        />
        <MetricTable title="Revisit & continuation" rows={report.revisit} />
        <MetricTable title="Archive exports & restores" rows={report.archiveOps} />
        <MetricTable title="Emotional legitimacy trend" rows={report.emotionalLegitimacyTrend} />
        <MetricTable
          title="Soft monetization observation"
          rows={[
            { id: "premium-state", label: "Premium state", value: report.premiumState },
            {
              id: "lines-seen",
              label: "Premium lines seen",
              value: String(report.monetizationObservation.premiumLinesSeen),
            },
            {
              id: "export-after",
              label: "Export after premium line",
              value: String(report.monetizationObservation.exportAfterPremium),
            },
            {
              id: "legitimacy-delta",
              label: "Legitimacy before → after",
              value: `${report.monetizationObservation.legitimacyBeforeExposure ?? "—"} → ${report.monetizationObservation.legitimacyAfterExposure ?? "—"}`,
            },
          ]}
        />
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <MetricTable
          title="Willingness-to-pay observation"
          rows={[
            {
              id: "would-pay",
              label: "Would pay",
              value: String(report.willingness.summary.wouldPay),
            },
            {
              id: "maybe",
              label: "Maybe",
              value: String(report.willingness.summary.maybe),
            },
            {
              id: "unlikely",
              label: "Unlikely",
              value: String(report.willingness.summary.unlikely),
            },
            {
              id: "behavioral",
              label: "Behavioral signals",
              value: String(report.willingness.summary.behavioralCount),
            },
          ]}
        />
        <RankedList
          title="Willingness behavioral signals"
          rows={report.willingness.behavioral.map((row) => ({
            id: row.id,
            label: row.label,
            detail: row.detail,
          }))}
          empty="No behavioral willingness signals yet."
        />
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <RankedList
          title="Remembered-later callbacks"
          rows={report.rememberedLater}
          empty="No remembered-later callbacks."
        />
        <RankedList
          title="Archive attachment signals"
          rows={report.attachment.signals.map((row) => ({
            id: row.id,
            label: row.label,
            detail: row.detail,
          }))}
          empty="No attachment signals yet."
        />
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <RankedList title="Trust failures" rows={report.trustFailures} empty="No trust failures." />
        <RankedList title="Sync failures" rows={report.syncFailures} empty="No sync failures." />
      </div>

      {report.warnings.warnings.length > 0 ? (
        <Card className="border-amber-900/30">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-normal text-amber-200/90">Founder warnings</CardTitle>
          </CardHeader>
          <CardContent>
            <ul className="space-y-2 text-sm text-zinc-400">
              {report.warnings.warnings.map((row) => (
                <li key={row.id}>
                  {row.severity === "concern" ? "⚠" : "·"} {row.label} — {row.detail}
                </li>
              ))}
            </ul>
          </CardContent>
        </Card>
      ) : null}

      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-sm font-normal text-zinc-200">Rollout gate checks</CardTitle>
        </CardHeader>
        <CardContent>
          <ul className="space-y-2 text-sm text-zinc-400">
            {report.rollout.checks.map((check) => (
              <li key={check.id}>
                {check.ok ? "✓" : "○"} {check.label} — {check.detail}
              </li>
            ))}
          </ul>
        </CardContent>
      </Card>

      <div className="flex flex-wrap gap-3 text-sm">
          <Link href="/debug/archive-value" className="text-zinc-500 hover:text-zinc-300">
            Archive value →
          </Link>
          <Link href="/debug/user-review" className="text-zinc-500 hover:text-zinc-300">
          User review →
        </Link>
        <Link href="/debug/retention-study" className="text-zinc-500 hover:text-zinc-300">
          Retention study →
        </Link>
      </div>
    </div>
  );
}
