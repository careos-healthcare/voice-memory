"use client";

import { Download } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { downloadPilotReviewJson, pilotSuppressionLabel } from "@/lib/debug/pilot-review";
import {
  pilotAccessStatusLabel,
  pilotFounderLabelText,
} from "@/lib/pilot/pilot-copy";
import type { PilotReviewReport } from "@/types/pilot-system";

function CandidateList({
  title,
  rows,
  empty,
}: {
  title: string;
  rows: Array<{ id: string; label: string; detail: string; score?: number }>;
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
                {row.score !== undefined ? ` (${row.score})` : ""}
                {row.detail ? <span className="text-zinc-600"> — {row.detail}</span> : null}
              </li>
            ))}
          </ul>
        )}
      </CardContent>
    </Card>
  );
}

export function PilotReviewPanel({ report }: { report: PilotReviewReport }) {
  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <p className="text-sm text-zinc-500">
          Founder-led pilot review — 10–20 users max, manual approval, no automatic checkout.
        </p>
        <Button type="button" variant="secondary" size="sm" onClick={() => downloadPilotReviewJson(report)}>
          <Download className="h-4 w-4" />
          Export JSON
        </Button>
      </div>

      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardHeader className="pb-1">
            <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">Approved</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold tabular-nums text-white">{report.access.approvedCount}</p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-1">
            <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">Capacity left</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold tabular-nums text-white">{report.access.capacityRemaining}</p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-1">
            <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">Archive maturity</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold tabular-nums text-white">{report.archiveMaturity}</p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-1">
            <CardTitle className="text-xs font-normal uppercase tracking-wider text-zinc-500">Legitimacy</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold tabular-nums text-white">{report.monetizationLegitimacy}</p>
          </CardContent>
        </Card>
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <CandidateList
          title="Strongest attachment candidates"
          rows={report.strongestAttachment}
          empty="No attachment signals yet."
        />
        <CandidateList
          title="Safest pilot candidates"
          rows={report.safestPilotCandidates}
          empty="No pilot candidates scored yet."
        />
        <CandidateList
          title="Trust-risk users"
          rows={report.trustRiskUsers}
          empty="No trust-risk users flagged."
        />
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-normal text-zinc-200">Pilot interest</CardTitle>
          </CardHeader>
          <CardContent className="space-y-1 text-sm text-zinc-400">
            <p>Page views: {report.interest.summary.pageViews}</p>
            <p>Pricing opens: {report.interest.summary.pricingOpens}</p>
            <p>Payment questions: {report.interest.summary.paymentQuestions}</p>
            <p>Revisit after pilot: {report.interest.summary.revisitAfterPilot}</p>
            <p>Trust drops: {report.interest.summary.trustDrops}</p>
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-sm font-normal text-zinc-200">Trust impact after pilot exposure</CardTitle>
        </CardHeader>
        <CardContent className="text-sm text-zinc-400">
          Legitimacy {report.trustImpactAfterExposure.before ?? "—"} →{" "}
          {report.trustImpactAfterExposure.after ?? "—"}
        </CardContent>
      </Card>

      {report.restraint.suppressionReasons.length > 0 ? (
        <Card className="border-amber-900/30">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-normal text-amber-200/90">Pilot suppression reasons</CardTitle>
          </CardHeader>
          <CardContent>
            <ul className="space-y-2 text-sm text-zinc-400">
              {report.restraint.suppressionReasons.map((reason) => (
                <li key={reason}>{pilotSuppressionLabel(reason)}</li>
              ))}
            </ul>
          </CardContent>
        </Card>
      ) : null}

      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-sm font-normal text-zinc-200">Access roster</CardTitle>
        </CardHeader>
        <CardContent>
          {report.access.roster.length === 0 ? (
            <p className="text-sm text-zinc-500">No pilot access records yet.</p>
          ) : (
            <ul className="space-y-2 text-sm text-zinc-400">
              {report.access.roster.map((row) => (
                <li key={row.participantId}>
                  {row.label ?? row.participantId.slice(0, 8)} — {pilotAccessStatusLabel(row.status)}
                </li>
              ))}
            </ul>
          )}
        </CardContent>
      </Card>

      {report.interest.founderLabels.length > 0 ? (
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-normal text-zinc-200">Founder labels</CardTitle>
          </CardHeader>
          <CardContent>
            <ul className="space-y-2 text-sm text-zinc-400">
              {report.interest.founderLabels.map((row) => (
                <li key={row.id}>
                  {pilotFounderLabelText(row.label)}
                  {row.note ? <span className="text-zinc-600"> — {row.note}</span> : null}
                </li>
              ))}
            </ul>
          </CardContent>
        </Card>
      ) : null}
    </div>
  );
}
