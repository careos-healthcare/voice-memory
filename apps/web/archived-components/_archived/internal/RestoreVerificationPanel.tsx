import Link from "next/link";

import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import { buildRestoreProductionReport } from "@/lib/mobile/restore-production-verification";
import type { RestoreReadinessStatus } from "@/types/restore-production-verification";

function statusClass(status: RestoreReadinessStatus): string {
  if (status === "PASSING") return "text-emerald-400/90";
  if (status === "FAILING") return "text-red-300/90";
  return "text-zinc-500";
}

export function RestoreVerificationPanel() {
  const report = buildRestoreProductionReport();
  const e = report.evidence;

  return (
    <div className="space-y-6" data-testid="restore-verification-panel">
      <Card className="border-white/10 bg-zinc-900/50">
        <CardHeader className="pb-2">
          <CardTitle className="text-base text-zinc-200">Restore production status</CardTitle>
          <p className="text-xs text-zinc-500">
            PASSING only when committed evidence has success=true after purchase → delete →
            reinstall → restore on a physical device.
          </p>
        </CardHeader>
        <CardContent>
          <p className={`text-2xl font-semibold ${statusClass(report.status)}`}>
            {report.status}
          </p>
          <p className="mt-2 text-sm text-zinc-500">{report.summary}</p>
        </CardContent>
      </Card>

      <Card className="border-white/10 bg-zinc-900/50">
        <CardHeader className="pb-2">
          <CardTitle className="text-base text-zinc-200">Verification flow</CardTitle>
        </CardHeader>
        <CardContent className="space-y-2 text-sm text-zinc-400">
          <ol className="list-inside list-decimal space-y-1">
            <li>Purchase (sandbox subscription)</li>
            <li>Delete the app from the device</li>
            <li>Reinstall from TestFlight or Play internal</li>
            <li>Restore purchases on fresh install</li>
          </ol>
          <p className="text-xs text-zinc-600">
            Flutter: Settings → Restore production verify (
            <code className="text-zinc-500">/restore-production-verify</code>)
          </p>
        </CardContent>
      </Card>

      <Card className="border-white/10 bg-zinc-900/50">
        <CardHeader className="pb-2">
          <CardTitle className="text-base text-zinc-200">Committed evidence</CardTitle>
          <p className="text-xs text-zinc-500">
            <code className="text-zinc-400">mobile/evidence/restore_purchases_tested.json</code>
          </p>
        </CardHeader>
        <CardContent className="space-y-3 text-sm text-zinc-400">
          {e ? (
            <dl className="grid gap-2 sm:grid-cols-2">
              <Row label="success" value={String(e.success)} />
              <Row label="platform" value={e.platform || "—"} />
              <Row label="device" value={e.device || "—"} />
              <Row label="timestamp" value={e.timestamp || "—"} />
            </dl>
          ) : (
            <p>No evidence file — status stays UNKNOWN.</p>
          )}
          {report.missingRequirements.length > 0 ? (
            <p className="text-xs text-amber-200/80">
              Missing for PASSING: {report.missingRequirements.join(", ")}
            </p>
          ) : null}
        </CardContent>
      </Card>

      <p className="text-xs text-zinc-600">
        Restore UI in app: {report.structuralRestorePresent ? "yes" : "no"} ·{" "}
        {report.generatedAt}
      </p>

      <div className="flex flex-wrap gap-3 text-sm">
        <Link href="/internal/mobile-readiness" className="text-violet-300 hover:text-violet-200">
          Mobile readiness →
        </Link>
        <Link
          href="/internal/revenuecat-verification"
          className="text-violet-300 hover:text-violet-200"
        >
          RevenueCat verification →
        </Link>
      </div>
    </div>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <dt className="text-xs text-zinc-600">{label}</dt>
      <dd className="text-zinc-300">{value}</dd>
    </div>
  );
}
