import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import type {
  CommercialReadinessStatus,
  StorePlatformReadinessReport,
} from "@/types/mobile-commercial-readiness";

function statusClass(status: CommercialReadinessStatus): string {
  if (status === "PASSING") return "text-emerald-400/90";
  if (status === "FAILING") return "text-red-300/90";
  return "text-zinc-500";
}

type CommercialReadinessPanelProps = {
  report: StorePlatformReadinessReport;
  title: string;
};

export function CommercialReadinessPanel({
  report,
  title,
}: CommercialReadinessPanelProps) {
  return (
    <div className="space-y-6" data-testid={`commercial-readiness-${report.platform}`}>
      <Card className="border-white/10 bg-zinc-900/50">
        <CardHeader className="pb-2">
          <CardTitle className="text-base text-zinc-200">{title}</CardTitle>
        </CardHeader>
        <CardContent>
          <p className={`text-2xl font-semibold ${statusClass(report.verdict)}`}>
            {report.verdict}
          </p>
          <p className="mt-1 text-sm text-zinc-500">
            {report.passingCount}/{report.total} passing — evidence from{" "}
            <code className="text-zinc-400">mobile/evidence/</code>
          </p>
        </CardContent>
      </Card>

      <div className="space-y-3">
        {report.items.map((item) => (
          <div
            key={item.id}
            className="rounded-lg border border-white/10 bg-zinc-900/40 px-3 py-3"
          >
            <div className="flex flex-wrap items-baseline justify-between gap-2">
              <span className="text-sm text-zinc-200">{item.label}</span>
              <span className={`text-xs font-medium uppercase ${statusClass(item.status)}`}>
                {item.status}
              </span>
            </div>
            <p className="mt-1 text-xs text-zinc-600">{item.evidenceFile}</p>
            {item.notes.length > 0 && (
              <ul className="mt-2 list-inside list-disc text-xs text-zinc-500">
                {item.notes.map((n) => (
                  <li key={n}>{n}</li>
                ))}
              </ul>
            )}
          </div>
        ))}
      </div>
    </div>
  );
}
