import Link from "next/link";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { buildStoreDistributionReadinessReport } from "@/lib/mobile/store-distribution-verification";
import type {
  StoreDistributionPillarRow,
  StorePlatformDistributionSection,
  StoreReadinessStatus,
} from "@/types/store-distribution-verification";

function statusClass(status: StoreReadinessStatus): string {
  if (status === "PASSING") return "text-emerald-400/90";
  if (status === "FAILING") return "text-red-300/90";
  return "text-zinc-500";
}

function PillarTable({ section }: { section: StorePlatformDistributionSection }) {
  return (
    <Card className="border-white/10 bg-zinc-900/50">
      <CardHeader className="pb-2">
        <CardTitle className="text-base text-zinc-200">
          {section.platform === "ios" ? "iOS" : "Android"}
        </CardTitle>
        <p className="text-xs text-zinc-500">
          Section verdict:{" "}
          <span className={statusClass(section.verdict)}>{section.verdict}</span>
        </p>
      </CardHeader>
      <CardContent>
        <table className="w-full text-sm text-zinc-400">
          <thead>
            <tr className="border-b border-white/5 text-left text-xs uppercase tracking-wide text-zinc-500">
              <th className="pb-2 pr-4">Pillar</th>
              <th className="pb-2">Status</th>
            </tr>
          </thead>
          <tbody>
            {section.pillars.map((row) => (
              <PillarRow key={row.id} row={row} />
            ))}
          </tbody>
        </table>
      </CardContent>
    </Card>
  );
}

function PillarRow({ row }: { row: StoreDistributionPillarRow }) {
  return (
    <tr className="border-b border-white/5 last:border-0">
      <td className="py-3 pr-4 align-top text-zinc-300">{row.label}</td>
      <td className="py-3 align-top">
        <span className={`font-medium ${statusClass(row.status)}`}>{row.status}</span>
        {row.missingRequirements.length > 0 && row.status !== "PASSING" ? (
          <p className="mt-1 text-xs text-amber-200/70">
            Needs: {row.missingRequirements.join(", ")}
          </p>
        ) : null}
        <p className="mt-1 text-xs text-zinc-600">{row.evidenceFiles.join(" · ")}</p>
      </td>
    </tr>
  );
}

export function StoreReadinessPanel() {
  const report = buildStoreDistributionReadinessReport();

  return (
    <div className="space-y-6" data-testid="store-readiness-panel">
      <Card className="border-white/10 bg-zinc-900/50">
        <CardHeader className="pb-2">
          <CardTitle className="text-base text-zinc-200">Store distribution proof</CardTitle>
          <p className="text-xs text-zinc-500">
            PASSING only from committed JSON under mobile/evidence/. No manual toggles.
            PRIMARY_PLATFORM requires signed build, store upload, install, purchase, and
            restore on both tracks.
          </p>
        </CardHeader>
        <CardContent className="grid gap-3 text-sm text-zinc-400 sm:grid-cols-2">
          <ProofRow label="TestFlight proof" passing={report.testflightProofPassing} />
          <ProofRow label="Play internal proof" passing={report.playProofPassing} />
          <ProofRow label="iOS signing" passing={report.iosSigningPassing} />
          <ProofRow label="Android signing" passing={report.androidSigningPassing} />
        </CardContent>
      </Card>

      <PillarTable section={report.ios} />
      <PillarTable section={report.android} />

      <Card className="border-white/10 bg-zinc-900/50">
        <CardHeader className="pb-2">
          <CardTitle className="text-base text-zinc-200">Evidence files</CardTitle>
        </CardHeader>
        <CardContent className="space-y-1 text-sm text-zinc-500">
          <p>
            <code className="text-zinc-400">testflight_tested.json</code> — upload, install,
            journey, purchase, restore on TestFlight
          </p>
          <p>
            <code className="text-zinc-400">play_internal_tested.json</code> — same on Play
            internal
          </p>
          <p>
            <code className="text-zinc-400">ios_signing_tested.json</code> — archive + ASC
            upload
          </p>
          <p>
            <code className="text-zinc-400">android_signing_tested.json</code> — signed AAB +
            Play Console upload
          </p>
          <p className="pt-2 text-xs text-zinc-600">
            Validators: validate:testflight-proof · validate:play-proof ·
            validate:ios-signing · validate:android-signing
          </p>
        </CardContent>
      </Card>

      <p className="text-xs text-zinc-600">
        <Link href="/internal/revenuecat-verification" className="text-violet-300 hover:text-violet-200">
          RevenueCat verification
        </Link>
        {" · "}
        <Link href="/internal/restore-verification" className="text-violet-300 hover:text-violet-200">
          Restore verification
        </Link>
        {" · "}
        <Link href="/internal/apple-store-readiness" className="text-violet-300 hover:text-violet-200">
          Apple checklist
        </Link>
        {" · "}
        <Link
          href="/internal/google-play-readiness"
          className="text-violet-300 hover:text-violet-200"
        >
          Google checklist
        </Link>
      </p>
    </div>
  );
}

function ProofRow({ label, passing }: { label: string; passing: boolean }) {
  return (
    <p>
      {label}:{" "}
      <span className={statusClass(passing ? "PASSING" : "FAILING")}>
        {passing ? "PASSING" : "FAILING"}
      </span>
    </p>
  );
}
