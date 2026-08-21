import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import type {
  NativePushPlatformReport,
  NativePushPlatformStatus,
} from "@/types/native-push-verification";

function statusClass(status: NativePushPlatformStatus): string {
  if (status === "PASSING") return "text-emerald-400/90";
  if (status === "FAILING") return "text-red-300/90";
  return "text-zinc-500";
}

function PlatformCard({ report }: { report: NativePushPlatformReport }) {
  const { evidence } = report;
  return (
    <Card
      className="border-white/10 bg-zinc-900/50"
      data-testid={`native-push-platform-${report.platform}`}
    >
      <CardHeader className="pb-2">
        <CardTitle className="text-base text-zinc-200">
          {report.platform === "ios" ? "iOS" : "Android"} status
        </CardTitle>
        <p className={`text-2xl font-semibold ${statusClass(report.status)}`}>
          {report.status}
        </p>
      </CardHeader>
      <CardContent className="space-y-2 text-xs text-zinc-500">
        <p>permission_granted: {evidence.permission_granted ? "yes" : "no"}</p>
        <p>notification_received: {evidence.notification_received ? "yes" : "no"}</p>
        <p>notification_opened: {evidence.notification_opened ? "yes" : "no"}</p>
        <p>
          archive_destination_verified:{" "}
          {evidence.archive_destination_verified ? "yes" : "no"}
        </p>
        <p>
          discover_destination_verified:{" "}
          {evidence.discover_destination_verified ? "yes" : "no"}
        </p>
        <p>record_destination_verified: {evidence.record_destination_verified ? "yes" : "no"}</p>
        <p>timestamp: {evidence.timestamp || "—"}</p>
        {report.missingSteps.length > 0 ? (
          <p className="text-amber-200/80">Missing: {report.missingSteps.join(", ")}</p>
        ) : null}
        {report.destinationGaps.length > 0 ? (
          <p className="text-amber-200/80">
            Routes still needed: {report.destinationGaps.join(", ")}
          </p>
        ) : null}
      </CardContent>
    </Card>
  );
}

type NativeMobilePushReadinessPanelProps = {
  report: import("@/types/native-push-verification").NativePushReadinessReport;
};

export function NativeMobilePushReadinessPanel({
  report,
}: NativeMobilePushReadinessPanelProps) {
  const overallPass =
    report.ios.status === "PASSING" && report.android.status === "PASSING";

  return (
    <div className="space-y-6" data-testid="native-mobile-push-readiness">
      <Card className="border-violet-500/20 bg-violet-950/20">
        <CardContent className="py-4 text-sm text-violet-100/80">
          Production FCM only — backend{" "}
          <code className="text-violet-200/90">POST /api/internal/send-test-push</code>. Local
          notifications do not count. PASSING requires iOS <strong>and</strong> Android evidence in{" "}
          <code className="text-violet-200/90">mobile/evidence/native_push_verification.json</code>.
        </CardContent>
      </Card>

      <Card className="border-white/10 bg-zinc-900/50">
        <CardContent className="py-4">
          <p className={`text-xl font-semibold ${statusClass(overallPass ? "PASSING" : report.ios.status === "UNKNOWN" && report.android.status === "UNKNOWN" ? "UNKNOWN" : "FAILING")}`}>
            {overallPass ? "PASSING" : report.ios.status === "UNKNOWN" || report.android.status === "UNKNOWN" ? "UNKNOWN" : "FAILING"}
          </p>
          <p className="mt-1 text-xs text-zinc-500">
            npm run validate:push-production
          </p>
        </CardContent>
      </Card>

      <div className="grid gap-4 sm:grid-cols-2">
        <PlatformCard report={report.ios} />
        <PlatformCard report={report.android} />
      </div>

      <Card className="border-white/10 bg-zinc-900/50">
        <CardHeader className="pb-2">
          <CardTitle className="text-base text-zinc-200">Deep link destinations</CardTitle>
        </CardHeader>
        <CardContent className="space-y-2 text-sm text-zinc-400">
          <p>Archive → /archive-belief</p>
          <p>Discover → /discover</p>
          <p>Record → /record</p>
          <p className="text-xs text-zinc-600">
            PushDeepLinkHandler records destination only when expectedRoute equals opened route.
          </p>
        </CardContent>
      </Card>

      {!report.evidence ? (
        <p className="text-xs text-red-300/80">native_push_verification.json not found</p>
      ) : null}
    </div>
  );
}
