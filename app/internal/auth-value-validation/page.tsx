import Link from "next/link";

import { AuthValueValidationPanel } from "@/components/internal/AuthValueValidationPanel";
import { SiteHeader } from "@/components/SiteHeader";
import { buildAuthValueValidationReport } from "@/lib/auth/auth-value-validation";

export default function AuthValueValidationPage() {
  const report = buildAuthValueValidationReport();

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-5xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <header className="mt-2">
          <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Founder only</p>
          <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
            Auth value validation
          </h1>
          <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
            Evidence phase: collect Protect Archive quotes (5–10 people) and paywall/device/mobile
            checklists per docs/AUTH_VALIDATION_EVIDENCE.md. Ignore conversion rates here until 10+
            real users.
          </p>
        </header>

        <div className="mt-8">
          <AuthValueValidationPanel report={report} />
        </div>

        <div className="mt-10 flex flex-wrap gap-3 text-sm">
          <Link href="/internal/founder-test" className="text-violet-300 hover:text-violet-200">
            Founder test checklist →
          </Link>
          <Link href="/archive-belief" className="text-violet-300 hover:text-violet-200">
            Archive belief (scenario #2) →
          </Link>
          <Link href="/" className="text-zinc-500 hover:text-zinc-300">
            Record (guest test) →
          </Link>
        </div>
        <p className="mt-4 font-mono text-xs text-zinc-600">
          Evidence log: docs/AUTH_VALIDATION_EVIDENCE.md
        </p>
      </div>
    </div>
  );
}
