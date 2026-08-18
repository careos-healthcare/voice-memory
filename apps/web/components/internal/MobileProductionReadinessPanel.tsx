import Link from "next/link";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type {
  MobileProductionReadinessReport,
  StoreReadinessStatus,
} from "@/types/mobile-production-readiness";

/** Status values: UNKNOWN | FAILING | PASSING */
function statusClass(status: StoreReadinessStatus): string {
  if (status === "PASSING") return "text-emerald-400/90";
  if (status === "FAILING") return "text-red-300/90";
  return "text-zinc-500"; /* UNKNOWN */
}

function PillarCard({
  title,
  pillar,
}: {
  title: string;
  pillar: MobileProductionReadinessReport["productReadiness"];
}) {
  return (
    <Card className="border-white/10 bg-zinc-900/50">
      <CardHeader className="pb-2">
        <CardTitle className="text-base text-zinc-200">{title}</CardTitle>
      </CardHeader>
      <CardContent>
        <p className={`text-2xl font-semibold ${statusClass(pillar.status)}`}>
          {pillar.status}
        </p>
        <p className="mt-1 text-sm text-zinc-500">
          {pillar.passing}/{pillar.total} passing · {pillar.summary}
        </p>
      </CardContent>
    </Card>
  );
}

type MobileProductionReadinessPanelProps = {
  report: MobileProductionReadinessReport;
};

export function MobileProductionReadinessPanel({
  report,
}: MobileProductionReadinessPanelProps) {
  return (
    <div className="space-y-6" data-testid="mobile-production-readiness">
      <div className="grid gap-4 sm:grid-cols-3">
        <PillarCard title="Product Readiness" pillar={report.productReadiness} />
        <PillarCard title="Store Readiness" pillar={report.storeReadiness} />
        <PillarCard title="Distribution Readiness" pillar={report.distributionReadiness} />
      </div>

      <Card className="border-white/10 bg-zinc-900/50">
        <CardHeader className="pb-2">
          <CardTitle className="text-base text-zinc-200">Store checklist</CardTitle>
          <p className="text-xs text-zinc-500">
            Evidence only — commit JSON under mobile/evidence/ or set MOBILE_EVIDENCE_* in CI.
          </p>
        </CardHeader>
        <CardContent className="space-y-4">
          {report.items.map((item) => (
            <div
              key={item.id}
              className="border-b border-white/5 pb-4 last:border-0"
              data-testid={`readiness-item-${item.id}`}
            >
              <p className={`text-sm font-medium ${statusClass(item.status)}`}>
                {item.label} — {item.status}
                {item.id === "revenuecat" ? (
                  <span className="ml-2 text-xs font-normal text-zinc-600">
                    (
                    <Link
                      href="/internal/revenuecat-verification"
                      className="text-violet-400/90 hover:underline"
                    >
                      verify
                    </Link>
                    )
                  </span>
                ) : null}
                {item.id === "restore_purchases" ? (
                  <span className="ml-2 text-xs font-normal text-zinc-600">
                    (
                    <Link
                      href="/internal/restore-verification"
                      className="text-violet-400/90 hover:underline"
                    >
                      verify
                    </Link>
                    )
                  </span>
                ) : null}
              </p>
              <p className="mt-1 text-xs text-zinc-600">
                Required: {item.requiredEvidence.join(", ")}
              </p>
              {item.evidenceNotes.length > 0 ? (
                <ul className="mt-2 space-y-1 text-xs leading-relaxed text-zinc-500">
                  {item.evidenceNotes.map((note) => (
                    <li key={note}>{note}</li>
                  ))}
                </ul>
              ) : null}
            </div>
          ))}
        </CardContent>
      </Card>

      <p className="text-xs text-zinc-600">
        {report.passingCount} passing · {report.failingCount} failing · {report.unknownCount}{" "}
        unknown · {report.generatedAt}
      </p>
    </div>
  );
}
