import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type { MobileWebParityAudit } from "@/lib/mobile/mobile-web-parity-audit";

function classificationClass(classification: string): string {
  if (classification === "needed_for_launch") return "text-emerald-400/90";
  if (classification === "remove_or_hide") return "text-red-300/90";
  if (classification === "web_only") return "text-sky-300/90";
  return "text-amber-300/90";
}

type MobileWebParityPanelProps = {
  audit: MobileWebParityAudit;
};

export function MobileWebParityPanel({ audit }: MobileWebParityPanelProps) {
  return (
    <div className="space-y-6" data-testid="mobile-web-parity-panel">
      <Card className="border-white/10 bg-zinc-900/50">
        <CardHeader>
          <CardTitle className="text-base text-zinc-100">Executive summary</CardTitle>
        </CardHeader>
        <CardContent className="space-y-3 text-sm leading-relaxed text-zinc-400">
          <p>
            <span className="text-zinc-300">Mobile gaps: </span>
            {audit.executiveSummary.mobileMissingLaunchCritical}
          </p>
          <p>
            <span className="text-zinc-300">Web legacy: </span>
            {audit.executiveSummary.webLegacySurfaces}
          </p>
          <p>
            <span className="text-zinc-300">Distribution: </span>
            {audit.executiveSummary.mobileFirstDistribution}
          </p>
          <p className="text-zinc-200">{audit.executiveSummary.recommendation}</p>
        </CardContent>
      </Card>

      <Card className="border-white/10 bg-zinc-900/50">
        <CardHeader>
          <CardTitle className="text-base text-zinc-100">Classification rules</CardTitle>
        </CardHeader>
        <CardContent className="space-y-2">
          {audit.classificationRules.map((rule) => (
            <div
              key={rule.id}
              className="rounded-lg border border-white/10 bg-zinc-950/40 px-3 py-2"
            >
              <p className={`text-xs font-medium uppercase ${classificationClass(rule.id)}`}>
                {rule.id}
              </p>
              <p className="mt-1 text-sm text-zinc-400">{rule.definition}</p>
            </div>
          ))}
        </CardContent>
      </Card>

      <div className="space-y-2">
        <h2 className="text-sm font-medium text-zinc-200">Feature comparison</h2>
        {audit.features.map((f) => (
          <div
            key={f.id}
            className="rounded-lg border border-white/10 bg-zinc-900/40 px-3 py-3"
          >
            <div className="flex flex-wrap items-baseline justify-between gap-2">
              <span className="text-sm font-medium text-zinc-100">{f.feature}</span>
              <span
                className={`text-xs font-medium uppercase ${classificationClass(f.classification)}`}
              >
                {f.classification}
              </span>
            </div>
            <p className="mt-1 text-xs text-zinc-500">
              Web: {f.web} · Mobile: {f.mobile}
            </p>
            <p className="mt-2 text-xs text-zinc-400">{f.decision}</p>
            <p className="mt-1 text-xs text-zinc-600">{f.action}</p>
          </div>
        ))}
      </div>

      <Card className="border-white/10 bg-zinc-900/50">
        <CardHeader>
          <CardTitle className="text-base text-zinc-100">Action plan</CardTitle>
        </CardHeader>
        <CardContent>
          <ol className="list-decimal space-y-2 pl-5 text-sm text-zinc-400">
            {audit.actionPlan.map((step) => (
              <li key={step}>{step}</li>
            ))}
          </ol>
        </CardContent>
      </Card>
    </div>
  );
}
