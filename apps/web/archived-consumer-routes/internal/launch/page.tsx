import Link from "next/link";

import { InternalHubDecisionHeader } from "@/archived-components/_archived/internal/InternalHubDecisionHeader";
import { LaunchReadinessPanel } from "@/archived-components/_archived/internal/LaunchReadinessPanel";
import { SiteHeader } from "@/components/SiteHeader";
import { buildLaunchReadinessReport } from "@/lib/internal/launch-readiness";

export default function InternalLaunchPage() {
  const report = buildLaunchReadinessReport();

  return (
    <div className="mx-auto max-w-5xl px-4 pb-20 sm:px-6">
      <SiteHeader />
      <InternalHubDecisionHeader
        route="/internal/launch"
        title="Launch readiness"
        subheadline="Mobile, store, distribution, revenue, and activation — single verdict."
        eyebrow="Launch"
      />

      <div className="mt-8">
        <LaunchReadinessPanel report={report} />
      </div>

      <div className="mt-10 flex flex-wrap gap-3 text-sm">
        <Link href="/internal/mobile-readiness" className="text-violet-300 hover:text-violet-200">
          Mobile readiness →
        </Link>
        <Link href="/internal" className="text-zinc-500 hover:text-zinc-300">
          ← Command center
        </Link>
      </div>
    </div>
  );
}
