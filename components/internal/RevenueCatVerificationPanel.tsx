import Link from "next/link";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { buildRevenueCatProductionReport } from "@/lib/mobile/revenuecat-production-verification";
import type { RevenueCatReadinessStatus } from "@/types/revenuecat-production-verification";

function statusClass(status: RevenueCatReadinessStatus): string {
  if (status === "PASSING") return "text-emerald-400/90";
  if (status === "FAILING") return "text-red-300/90";
  return "text-zinc-500";
}

export function RevenueCatVerificationPanel() {
  const report = buildRevenueCatProductionReport();
  const e = report.evidence;

  return (
    <div className="space-y-6" data-testid="revenuecat-verification-panel">
      <Card className="border-white/10 bg-zinc-900/50">
        <CardHeader className="pb-2">
          <CardTitle className="text-base text-zinc-200">RevenueCat production status</CardTitle>
          <p className="text-xs text-zinc-500">
            PASSING only when committed evidence shows a real purchase + entitlement + restore on
            device. Web cannot run the store SDK.
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
          <CardTitle className="text-base text-zinc-200">Committed evidence</CardTitle>
          <p className="text-xs text-zinc-500">
            <code className="text-zinc-400">mobile/evidence/revenuecat_store_tested.json</code>
          </p>
        </CardHeader>
        <CardContent className="space-y-3 text-sm text-zinc-400">
          {e ? (
            <dl className="grid gap-2 sm:grid-cols-2">
              <Row label="success" value={String(e.success)} />
              <Row label="platform" value={e.platform || "—"} />
              <Row label="device" value={e.device || "—"} />
              <Row label="timestamp" value={e.timestamp || "—"} />
              <Row label="offering_loaded" value={String(e.offering_loaded)} />
              <Row label="purchase_completed" value={String(e.purchase_completed)} />
              <Row label="entitlement_received" value={String(e.entitlement_received)} />
              <Row label="restore_completed" value={String(e.restore_completed)} />
              {e.sdk_initialized != null ? (
                <Row label="sdk_initialized (export)" value={String(e.sdk_initialized)} />
              ) : null}
              {e.app_user_id != null ? (
                <Row label="app_user_id (export)" value={e.app_user_id || "—"} />
              ) : null}
              {e.product_ids?.length ? (
                <Row label="product_ids" value={e.product_ids.join(", ")} />
              ) : null}
              {e.entitlement_ids?.length ? (
                <Row label="entitlement_ids" value={e.entitlement_ids.join(", ")} />
              ) : null}
            </dl>
          ) : (
            <p>No evidence file — status stays UNKNOWN until device export is committed.</p>
          )}
          {report.missingRequirements.length > 0 ? (
            <p className="text-xs text-amber-200/80">
              Missing for PASSING: {report.missingRequirements.join(", ")}
            </p>
          ) : null}
        </CardContent>
      </Card>

      <Card className="border-white/10 bg-zinc-900/50">
        <CardHeader className="pb-2">
          <CardTitle className="text-base text-zinc-200">On-device verification (Flutter)</CardTitle>
        </CardHeader>
        <CardContent className="space-y-2 text-sm text-zinc-400">
          <p>
            Open <strong className="font-normal text-zinc-300">Settings → RevenueCat verification</strong>{" "}
            or route <code className="text-zinc-500">/revenuecat-verify</code> on a physical device
            with sandbox credentials.
          </p>
          <p>Live debug panel shows:</p>
          <ul className="list-inside list-disc space-y-1 text-xs text-zinc-500">
            <li>SDK initialized</li>
            <li>Offerings loaded + product IDs</li>
            <li>Entitlement state</li>
            <li>Restore state</li>
            <li>Current RevenueCat app user ID</li>
          </ul>
          <p className="text-xs text-zinc-600">
            Export JSON → paste into{" "}
            <code className="text-zinc-500">revenuecat_store_tested.json</code> →{" "}
            <code className="text-zinc-500">npm run validate:revenuecat-production</code>
          </p>
        </CardContent>
      </Card>

      <p className="text-xs text-zinc-600">
        Structural SDK integrated: {report.structuralIntegrated ? "yes" : "no"} ·{" "}
        {report.generatedAt}
      </p>

      <div className="flex flex-wrap gap-3 text-sm">
        <Link href="/internal/mobile-readiness" className="text-violet-300 hover:text-violet-200">
          Mobile readiness →
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
