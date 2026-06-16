import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type { MobileFirstClassReport } from "@/types/mobile-first-class";

function statusClass(status: string): string {
  if (status === "PASSING" || status === "COMPLETE" || status === "PRIMARY_PLATFORM") {
    return "text-emerald-400/90";
  }
  if (status === "FAILING" || status === "MISSING" || status === "COMPANION_APP") {
    return "text-red-300/90";
  }
  return "text-amber-300/90";
}

type MobileFirstClassPanelProps = {
  report: MobileFirstClassReport;
  variant?: "full" | "parity" | "archive-review";
};

export function MobileFirstClassPanel({
  report,
  variant = "full",
}: MobileFirstClassPanelProps) {
  if (variant === "parity") {
    return (
      <div className="space-y-4" data-testid="mobile-parity-panel">
        <p className="text-sm text-zinc-400">
          {report.parity.completeCount} complete · {report.parity.partialCount} partial ·{" "}
          {report.parity.missingCount} missing
        </p>
        <div className="space-y-2">
          {report.parity.features.map((f) => (
            <div
              key={f.id}
              className="flex flex-wrap items-baseline justify-between gap-2 rounded-lg border border-white/10 bg-zinc-900/40 px-3 py-2"
            >
              <span className="text-sm text-zinc-200">{f.label}</span>
              <span className={`text-xs font-medium uppercase ${statusClass(f.status)}`}>
                {f.status}
              </span>
              <p className="w-full text-xs text-zinc-500">
                {f.mobileSurface}
                {f.notes.length ? ` — ${f.notes.join(" ")}` : ""}
              </p>
            </div>
          ))}
        </div>
      </div>
    );
  }

  if (variant === "archive-review") {
    return (
      <div className="space-y-3" data-testid="mobile-archive-review-panel">
        {report.archiveReview.questions.map((q) => (
          <div
            key={q.id}
            className="rounded-lg border border-white/10 bg-zinc-900/40 px-3 py-3"
          >
            <p className="text-sm text-zinc-200">{q.question}</p>
            <p
              className={`mt-1 text-xs font-medium uppercase ${q.answerableOnMobile ? "text-emerald-400/90" : "text-red-300/90"}`}
            >
              {q.answerableOnMobile ? "Yes — on mobile" : "No — blocked"}
            </p>
            {q.evidence.length > 0 && (
              <ul className="mt-2 list-inside list-disc text-xs text-zinc-500">
                {q.evidence.map((e) => (
                  <li key={e}>{e}</li>
                ))}
              </ul>
            )}
          </div>
        ))}
      </div>
    );
  }

  return (
    <div className="space-y-6" data-testid="mobile-first-class-panel">
      <Card className="border-white/10 bg-zinc-900/50">
        <CardHeader className="pb-2">
          <CardTitle className="text-base text-zinc-200">Founder verdict</CardTitle>
        </CardHeader>
        <CardContent>
          <p className={`text-2xl font-semibold ${statusClass(report.verdict)}`}>
            {report.verdict}
          </p>
          {report.verdictReasons.length > 0 && (
            <ul className="mt-3 list-inside list-disc text-sm text-zinc-500">
              {report.verdictReasons.map((r) => (
                <li key={r}>{r}</li>
              ))}
            </ul>
          )}
        </CardContent>
      </Card>

      <div className="grid gap-4 sm:grid-cols-3">
        {(
          [
            ["Product", report.productReadiness],
            ["Store", report.storeReadiness],
            ["Distribution", report.distributionReadiness],
          ] as const
        ).map(([title, pillar]) => (
          <Card key={title} className="border-white/10 bg-zinc-900/50">
            <CardHeader className="pb-2">
              <CardTitle className="text-base text-zinc-200">{title} readiness</CardTitle>
            </CardHeader>
            <CardContent>
              <p className={`text-xl font-semibold ${statusClass(pillar.status)}`}>
                {pillar.status}
              </p>
              <p className="mt-1 text-xs text-zinc-500">
                {pillar.passing}/{pillar.total} · {pillar.summary}
              </p>
            </CardContent>
          </Card>
        ))}
      </div>

      <Card className="border-white/10 bg-zinc-900/50">
        <CardHeader className="pb-2">
          <CardTitle className="text-base text-zinc-200">Mobile journey</CardTitle>
        </CardHeader>
        <CardContent className="space-y-2">
          {report.journey.steps.map((s) => (
            <div
              key={s.id}
              className="flex flex-wrap justify-between gap-2 text-sm border-b border-white/5 pb-2 last:border-0"
            >
              <span className="text-zinc-300">{s.label}</span>
              <span className="text-xs text-zinc-500">
                {s.reachableOnMobile && !s.requiresWeb ? "mobile" : s.requiresWeb ? "needs web" : "blocked"}
              </span>
            </div>
          ))}
        </CardContent>
      </Card>

      <Card className="border-white/10 bg-zinc-900/50">
        <CardHeader className="pb-2">
          <CardTitle className="text-base text-zinc-200">Native paywall audit</CardTitle>
        </CardHeader>
        <CardContent className="space-y-2">
          {report.paywall.checks.map((c) => (
            <div key={c.id} className="flex justify-between gap-2 text-sm">
              <span className="text-zinc-300">{c.label}</span>
              <span className={c.passed ? "text-emerald-400/90" : "text-red-300/90"}>
                {c.passed ? "pass" : "fail"}
              </span>
            </div>
          ))}
        </CardContent>
      </Card>

      {report.independence.violations.length > 0 && (
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-base text-zinc-200">Independence violations</CardTitle>
          </CardHeader>
          <CardContent>
            <ul className="list-inside list-disc text-sm text-zinc-500">
              {report.independence.violations.map((v) => (
                <li key={`${v.kind}-${v.detail}`}>
                  [{v.kind}] {v.detail}
                </li>
              ))}
            </ul>
          </CardContent>
        </Card>
      )}
    </div>
  );
}
