import { RestoreVerificationPanel } from "@/components/internal/RestoreVerificationPanel";
import { SiteHeader } from "@/components/SiteHeader";

export default function RestoreVerificationPage() {
  return (
    <div className="min-h-screen bg-zinc-950 pb-safe">
      <div className="mx-auto max-w-3xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <header className="mt-2">
          <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Founder only</p>
          <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
            Restore purchase verification
          </h1>
          <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
            Prove subscriptions survive delete and reinstall. Status is evidence-only — success
            must be true in committed JSON.
          </p>
        </header>

        <div className="mt-6">
          <RestoreVerificationPanel />
        </div>
      </div>
    </div>
  );
}
