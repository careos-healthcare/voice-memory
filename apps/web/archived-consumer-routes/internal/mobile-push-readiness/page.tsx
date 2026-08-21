import Link from "next/link";

import { NativeMobilePushReadinessPanel } from "@/archived-components/_archived/internal/NativeMobilePushReadinessPanel";
import { SiteHeader } from "@/components/SiteHeader";
import { buildNativePushReadinessReport } from "@/lib/mobile/native-push-verification";

export default function MobilePushReadinessPage() {
  const report = buildNativePushReadinessReport();

  return (
    <div className="min-h-screen bg-zinc-950 pb-safe">
      <div className="mx-auto max-w-3xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <header className="mt-2">
          <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Founder only</p>
          <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
            Native mobile push readiness
          </h1>
          <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
            Production FCM only (backend → device). PASSING requires iOS and Android each:
            permission, received, opened, and archive / discover / record destinations verified.
            Use <code className="text-zinc-500">/native-push-verify</code> on physical devices.
          </p>
        </header>

        <div className="mt-6">
          <NativeMobilePushReadinessPanel report={report} />
        </div>

        <div className="mt-8 flex flex-wrap gap-3 text-sm">
          <Link href="/internal/mobile-readiness" className="text-violet-300 hover:text-violet-200">
            Mobile readiness →
          </Link>
          <Link href="/internal/push-verification" className="text-zinc-500 hover:text-zinc-300">
            Web push verification (excluded) →
          </Link>
        </div>
      </div>
    </div>
  );
}
