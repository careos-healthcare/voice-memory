"use client";

import { Download } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  downloadArchiveValueReviewJson,
  premiumStateLabel,
  suppressionReasonLabel,
} from "@/lib/debug/archive-value-review";
import type { ArchiveValueReviewReport } from "@/types/monetization-validation";

export function ArchiveValuePanel({ report }: { report: ArchiveValueReviewReport }) {
  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <p className="text-sm text-zinc-500">
          Soft monetization validation — archive protection interest without trust damage.
        </p>
        <Button type="button" variant="secondary" size="sm" onClick={() => downloadArchiveValueReviewJson(report)}>
          <Download className="h-4 w-4" />
          Export JSON
        </Button>
      </div>

      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardHeader className="pb-1">
            <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
              Premium state
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-lg font-semibold text-white">{premiumStateLabel(report.premiumState)}</p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-1">
            <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
              Protection interest
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold tabular-nums text-white">{report.archiveProtectionInterest}</p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-1">
            <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
              Premium lines seen
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold tabular-nums text-white">
              {report.observation.premiumLinesSeen}
            </p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-1">
            <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">
              Legitimacy delta
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-lg font-semibold tabular-nums text-white">
              {report.legitimacyBeforeExposure ?? "—"} → {report.legitimacyAfterExposure ?? "—"}
            </p>
          </CardContent>
        </Card>
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-normal text-zinc-200">Strongest attachment signals</CardTitle>
          </CardHeader>
          <CardContent>
            <ul className="space-y-2 text-sm text-zinc-400">
              {report.attachmentSignals.length === 0 ? (
                <li className="text-zinc-500">No attachment signals yet.</li>
              ) : (
                report.attachmentSignals.map((row) => (
                  <li key={row.id}>
                    {row.label} — {row.detail}
                  </li>
                ))
              )}
            </ul>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-normal text-zinc-200">Safest monetization moments</CardTitle>
          </CardHeader>
          <CardContent>
            <ul className="space-y-2 text-sm text-zinc-400">
              {report.safestMoments.length === 0 ? (
                <li className="text-zinc-500">None detected yet.</li>
              ) : (
                report.safestMoments.map((row) => (
                  <li key={row.id}>
                    {row.label} — {row.detail}
                  </li>
                ))
              )}
            </ul>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-normal text-zinc-200">Trust-risk moments</CardTitle>
          </CardHeader>
          <CardContent>
            <ul className="space-y-2 text-sm text-zinc-400">
              {report.trustRiskMoments.length === 0 ? (
                <li className="text-zinc-500">None flagged.</li>
              ) : (
                report.trustRiskMoments.map((row) => (
                  <li key={row.id}>
                    {row.label} — {row.detail}
                  </li>
                ))
              )}
            </ul>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-normal text-zinc-200">Premium suppression reasons</CardTitle>
          </CardHeader>
          <CardContent>
            <ul className="space-y-2 text-sm text-zinc-400">
              {report.suppressionReasons.length === 0 ? (
                <li className="text-zinc-500">No active suppressions.</li>
              ) : (
                report.suppressionReasons.map((reason) => (
                  <li key={reason}>{suppressionReasonLabel(reason)}</li>
                ))
              )}
            </ul>
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-sm font-normal text-zinc-200">WTP evolution</CardTitle>
        </CardHeader>
        <CardContent>
          <ul className="space-y-2 text-sm text-zinc-400">
            {report.wtpEvolution.length === 0 ? (
              <li className="text-zinc-500">No WTP evolution recorded.</li>
            ) : (
              report.wtpEvolution.map((row, index) => (
                <li key={`${row.at}-${index}`}>
                  {row.at}: {row.label} — {row.detail}
                </li>
              ))
            )}
          </ul>
        </CardContent>
      </Card>

      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-sm font-normal text-zinc-200">Monetization observation</CardTitle>
        </CardHeader>
        <CardContent className="space-y-1 text-sm text-zinc-400">
          <p>Backup after premium line: {report.observation.backupAfterPremium}</p>
          <p>Export after premium line: {report.observation.exportAfterPremium}</p>
          <p>Revisit after premium line: {report.observation.revisitAfterPremium}</p>
          <p>Trust drop after premium line: {report.observation.trustDropAfterPremium}</p>
          <p>Session abandon after premium line: {report.observation.sessionAbandonAfterPremium}</p>
        </CardContent>
      </Card>
    </div>
  );
}
