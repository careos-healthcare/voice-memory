"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type { DistributionReport } from "@/types/distribution";

type DistributionReportPanelProps = {
  report: DistributionReport;
};

export function DistributionReportPanel({ report }: DistributionReportPanelProps) {
  const { rates } = report;

  return (
    <div className="space-y-6" data-testid="distribution-report-panel">
      <Card className="border-white/10 bg-zinc-900/50">
        <CardHeader>
          <CardTitle className="text-lg text-white">Distribution Score</CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-4xl font-semibold tabular-nums text-violet-200">
            {rates.distributionScore}
          </p>
          <dl className="mt-4 grid gap-3 sm:grid-cols-2">
            <Metric label="Share rate" value={rates.shareRate} />
            <Metric label="Referral rate" value={rates.referralRate} />
            <Metric label="Testimonial rate" value={rates.testimonialRate} />
            <Metric label="Creator story rate" value={rates.creatorStoryRate} />
          </dl>
        </CardContent>
      </Card>

      <Card className="border-white/10 bg-zinc-900/50">
        <CardHeader>
          <CardTitle className="text-lg text-white">Why people share</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4 text-sm text-zinc-400">
          <Section title="Sharing moments" items={report.topSharingMoments} />
          <Section title="Referral moments" items={report.topReferralMoments} />
          <Section title="Testimonial moments" items={report.topTestimonialMoments} />
        </CardContent>
      </Card>

      <Card className="border-white/10 bg-zinc-900/50">
        <CardHeader>
          <CardTitle className="text-lg text-white">Moment attribution</CardTitle>
        </CardHeader>
        <CardContent>
          <ul className="space-y-2 text-sm text-zinc-400">
            {report.momentAttribution.map((row) => (
              <li key={row.momentType} className="flex flex-wrap justify-between gap-2">
                <span>{row.label}</span>
                <span className="font-mono text-xs text-zinc-500">
                  share {row.shareCount} · referral {row.referralCount} · testimonial{" "}
                  {row.testimonialCount}
                </span>
              </li>
            ))}
          </ul>
        </CardContent>
      </Card>

      {report.testimonialSamples.length > 0 ? (
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader>
            <CardTitle className="text-lg text-white">Testimonial samples</CardTitle>
          </CardHeader>
          <CardContent>
            <ul className="space-y-2 text-sm italic text-zinc-400">
              {report.testimonialSamples.map((text, index) => (
                <li key={index}>"{text}"</li>
              ))}
            </ul>
          </CardContent>
        </Card>
      ) : null}
    </div>
  );
}

function Metric({ label, value }: { label: string; value: number | null }) {
  return (
    <div>
      <dt className="text-xs uppercase tracking-wide text-zinc-600">{label}</dt>
      <dd className="mt-0.5 text-lg text-zinc-200">
        {value !== null ? `${value}%` : "—"}
      </dd>
    </div>
  );
}

function Section({ title, items }: { title: string; items: string[] }) {
  if (items.length === 0) {
    return (
      <div>
        <p className="text-xs uppercase tracking-wide text-zinc-600">{title}</p>
        <p className="mt-1 text-zinc-600">No signals yet.</p>
      </div>
    );
  }
  return (
    <div>
      <p className="text-xs uppercase tracking-wide text-zinc-600">{title}</p>
      <ul className="mt-1 list-disc pl-5">
        {items.map((item) => (
          <li key={item}>{item}</li>
        ))}
      </ul>
    </div>
  );
}
