"use client";

import type { OrganicReferralReport } from "@/types/organic-referral";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

interface OrganicReferralPanelProps {
  report: OrganicReferralReport;
}

function verdictColor(verdict: OrganicReferralReport["verdict"]): string {
  switch (verdict) {
    case "strong":
      return "text-emerald-300";
    case "weak":
      return "text-amber-300";
    case "mixed":
      return "text-violet-300";
    default:
      return "text-zinc-500";
  }
}

export function OrganicReferralPanel({ report }: OrganicReferralPanelProps) {
  return (
    <div className="space-y-6">
      <Card className="border-sky-500/25 bg-zinc-900/50">
        <CardHeader>
          <CardTitle className="text-lg text-white">Critical output</CardTitle>
          <p className="text-sm font-medium text-sky-200/90">{report.criticalQuestion}</p>
        </CardHeader>
        <CardContent>
          <p className="text-sm leading-relaxed text-zinc-300">{report.criticalAnswer}</p>
          <p className={`mt-3 text-xs uppercase tracking-wider ${verdictColor(report.verdict)}`}>
            Verdict: {report.verdict}
            {report.referralRate !== null
              ? ` · ${report.referralRate}% Yes (strong ≥20%, weak <10% Yes)`
              : ""}
            {report.yesOrThoughtRate !== null
              ? ` · ${report.yesOrThoughtRate}% Yes or Thought (strong ≥40%)`
              : ""}
          </p>
          <p className="mt-2 text-xs text-zinc-500">
            {report.totalResponses} responses on this device
            {report.thoughtAboutItRate !== null
              ? ` · ${report.thoughtAboutItRate}% Thought about it`
              : ""}
          </p>
        </CardContent>
      </Card>

      <Card className="border-violet-500/20 bg-zinc-900/50">
        <CardHeader>
          <CardTitle className="text-lg text-white">Organic referral</CardTitle>
          <p className="text-sm text-zinc-400">
            Whether users naturally want to tell someone — not marketing referrals or invite
            systems. Device-local.
          </p>
        </CardHeader>
        <CardContent className="space-y-6 text-sm">
          <div className="grid gap-4 sm:grid-cols-3">
            <div>
              <p className="text-xs uppercase tracking-wider text-zinc-500">Referral rate</p>
              <p className="mt-1 text-2xl tabular-nums text-white">
                {report.referralRate ?? "—"}
                {report.referralRate !== null ? "%" : ""}
              </p>
              <p className="text-xs text-zinc-500">Yes</p>
            </div>
            <div>
              <p className="text-xs uppercase tracking-wider text-zinc-500">Thought-about-it rate</p>
              <p className="mt-1 text-2xl tabular-nums text-white">
                {report.thoughtAboutItRate ?? "—"}
                {report.thoughtAboutItRate !== null ? "%" : ""}
              </p>
            </div>
            <div>
              <p className="text-xs uppercase tracking-wider text-zinc-500">Yes or Thought</p>
              <p className="mt-1 text-2xl tabular-nums text-white">
                {report.yesOrThoughtRate ?? "—"}
                {report.yesOrThoughtRate !== null ? "%" : ""}
              </p>
            </div>
          </div>

          {report.referralReasons.length > 0 ? (
            <div>
              <p className="text-xs uppercase tracking-wider text-zinc-500">Referral reasons</p>
              <ul className="mt-2 space-y-1 text-zinc-400">
                {report.referralReasons.map((row) => (
                  <li key={row.id}>
                    {row.label}: {row.count} ({row.sharePercent}%)
                  </li>
                ))}
              </ul>
            </div>
          ) : null}

          {report.referralBlockers.length > 0 ? (
            <div>
              <p className="text-xs uppercase tracking-wider text-zinc-500">Referral blockers</p>
              <ul className="mt-2 space-y-1 text-zinc-400">
                {report.referralBlockers.map((row) => (
                  <li key={row.id}>
                    {row.label}: {row.count} ({row.sharePercent}%)
                  </li>
                ))}
              </ul>
            </div>
          ) : null}

          {report.byStatusOutcomes.length > 0 ? (
            <div className="overflow-x-auto">
              <p className="mb-2 text-xs uppercase tracking-wider text-zinc-500">
                Referral vs outcomes
              </p>
              <table className="w-full min-w-[520px] text-left text-xs">
                <thead>
                  <tr className="border-b border-zinc-800 text-zinc-500">
                    <th className="py-2 pr-3 font-normal">Status</th>
                    <th className="py-2 pr-3 font-normal">n</th>
                    <th className="py-2 pr-3 font-normal">7d retention</th>
                    <th className="py-2 pr-3 font-normal">Attachment</th>
                    <th className="py-2 pr-3 font-normal">Subscribe</th>
                  </tr>
                </thead>
                <tbody>
                  {report.byStatusOutcomes.map((row) => (
                    <tr key={row.status} className="border-b border-zinc-800/60 text-zinc-300">
                      <td className="py-2 pr-3">{row.label}</td>
                      <td className="py-2 pr-3 tabular-nums">{row.count}</td>
                      <td className="py-2 pr-3 tabular-nums">
                        {row.retentionRate ?? "—"}
                        {row.retentionRate !== null ? "%" : ""}
                      </td>
                      <td className="py-2 pr-3 tabular-nums">
                        {row.attachmentRate ?? "—"}
                        {row.attachmentRate !== null ? "%" : ""}
                      </td>
                      <td className="py-2 pr-3 tabular-nums">
                        {row.subscriptionRate ?? "—"}
                        {row.subscriptionRate !== null ? "%" : ""}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : null}
        </CardContent>
      </Card>
    </div>
  );
}
