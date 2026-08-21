import Link from "next/link";

import { MobileWebParityPanel } from "@/archived-components/_archived/internal/MobileWebParityPanel";
import { SiteHeader } from "@/components/SiteHeader";
import {
  buildMobileWebParityAudit,
  countByClassification,
} from "@/lib/mobile/mobile-web-parity-audit";

export default function MobileWebParityPage() {
  const audit = buildMobileWebParityAudit();
  const counts = countByClassification(audit);

  return (
    <div className="min-h-screen bg-zinc-950 pb-safe">
      <div className="mx-auto max-w-4xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <header className="mt-2">
          <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Founder only</p>
          <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
            Mobile / web parity audit
          </h1>
          <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
            Classification of web/PWA surfaces vs Flutter — what to port, defer, keep web-only, or
            hide. Not a blind porting checklist.
          </p>
          <p className="mt-3 text-xs text-zinc-500">
            {counts.needed_for_launch} launch · {counts.later} later · {counts.web_only} web-only ·{" "}
            {counts.remove_or_hide} remove/hide
          </p>
        </header>

        <div className="mt-6">
          <MobileWebParityPanel audit={audit} />
        </div>

        <p className="mt-6 text-xs text-zinc-600">
          Report file:{" "}
          <code className="text-zinc-500">docs/MOBILE_WEB_PARITY_AUDIT.md</code> (
          <code className="text-zinc-500">npm run generate:mobile-web-parity-audit</code>)
        </p>

        <div className="mt-8 flex flex-wrap gap-3 text-sm">
          <Link href="/internal/mobile-parity" className="text-violet-300 hover:text-violet-200">
            Feature parity matrix →
          </Link>
          <Link href="/internal/mobile-readiness" className="text-violet-300 hover:text-violet-200">
            Mobile readiness →
          </Link>
        </div>
      </div>
    </div>
  );
}
