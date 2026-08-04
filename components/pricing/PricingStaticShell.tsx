import { LANDING_3_DAY_CHALLENGE } from "@/lib/product/landing-three-day-challenge-copy";

/** Server-rendered plan honesty — visible in initial HTML for tests and no-JS users. */
export function PricingStaticShell() {
  return (
    <section
      data-pricing-ssr
      data-billing-state="mobile-store-only"
      className="mt-2 rounded-2xl border border-white/10 bg-white/[0.02] px-4 py-5 sm:px-5"
      aria-label="Plans overview"
    >
      <p className="text-xs uppercase tracking-[0.2em] text-violet-200">
        {LANDING_3_DAY_CHALLENGE.pricing.pageEyebrow}
      </p>
      <h1 className="mt-2 text-2xl font-semibold tracking-tight text-white sm:text-3xl">
        {LANDING_3_DAY_CHALLENGE.pricing.pageTitle}
      </h1>
      <p className="mt-3 text-sm leading-relaxed text-zinc-300">
        {LANDING_3_DAY_CHALLENGE.pricing.pageLead}
      </p>
      <div className="mt-4 grid gap-3 sm:grid-cols-2">
        <div
          data-pricing-plan="free"
          className="rounded-xl border border-white/10 p-3"
        >
          <p className="text-lg font-medium text-zinc-100">Free</p>
          <p className="mt-1 text-sm text-zinc-300">Free</p>
        </div>
        <div
          data-pricing-plan="pro"
          className="rounded-xl border border-violet-400/25 p-3"
        >
          <p className="text-lg font-medium text-zinc-100">Pro</p>
          <p className="mt-1 text-sm text-zinc-300">
            Store price shown in the ArchiveMe mobile app
          </p>
          <p className="mt-2 text-xs text-muted">
            Monthly and annual subscriptions are sold through the app stores.
          </p>
        </div>
      </div>
      <p
        className="mt-4 text-xs leading-relaxed text-muted"
        data-checkout-availability
      >
        This website does not sell subscriptions. Existing original content
        remains accessible.
      </p>
    </section>
  );
}
