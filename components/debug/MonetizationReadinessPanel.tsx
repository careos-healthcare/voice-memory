"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type { MonetizationReadinessReport, ReadinessCheck } from "@/types/observation-workflow";

function CheckList({ title, checks }: { title: string; checks: ReadinessCheck[] }) {
  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="text-sm font-normal text-zinc-300">{title}</CardTitle>
      </CardHeader>
      <CardContent>
        <ul className="space-y-2">
          {checks.map((row) => (
            <li key={row.id} className="rounded-lg bg-white/[0.03] px-3 py-2 text-sm">
              <p className={row.status === "pass" ? "text-emerald-300/90" : row.status === "fail" ? "text-red-300/90" : "text-amber-200/90"}>
                {row.label} — {row.status}
              </p>
              <p className="mt-1 text-xs text-zinc-600">{row.detail}</p>
            </li>
          ))}
        </ul>
      </CardContent>
    </Card>
  );
}

export function MonetizationReadinessPanel({ report }: { report: MonetizationReadinessReport }) {
  return (
    <div className="space-y-6">
      <Card className={report.verdict === "test_carefully" ? "border-emerald-900/40" : "border-red-900/40"}>
        <CardHeader className="pb-2">
          <CardTitle className="text-lg font-normal text-zinc-100">{report.headline}</CardTitle>
        </CardHeader>
        <CardContent className="space-y-2 text-sm text-zinc-400">
          <p>{report.stripeRecommendation}</p>
          <p className="text-xs text-zinc-600">No Stripe integration on this page — gate only.</p>
        </CardContent>
      </Card>

      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-sm font-normal text-zinc-300">Soft monetization observation</CardTitle>
        </CardHeader>
        <CardContent className="space-y-2 text-sm text-zinc-400">
          <p>Archive protection interest: {report.archiveProtectionInterest}</p>
          <p>Premium lines seen: {report.softMonetization.premiumLinesSeen}</p>
          <p>
            Legitimacy before → after exposure:{" "}
            {report.softMonetization.legitimacyBeforeExposure ?? "—"} →{" "}
            {report.softMonetization.legitimacyAfterExposure ?? "—"}
          </p>
          <p className="text-xs text-zinc-600">Archive protection framing only — no Stripe on this page.</p>
        </CardContent>
      </Card>

      <div className="grid gap-4 lg:grid-cols-2">
        <CheckList title="Retention thresholds" checks={report.retentionChecks} />
        <CheckList title="Moat metrics" checks={report.moatChecks} />
        <CheckList title="Trust readiness" checks={report.trustChecks} />
        <CheckList title="Sync reliability" checks={report.syncChecks} />
        <CheckList title="Archive export / restore" checks={report.archiveChecks} />
      </div>
    </div>
  );
}
