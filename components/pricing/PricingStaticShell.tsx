import type { PricingSsrSnapshot } from "@/lib/billing/pricing-ssr-snapshot";
import { getPricingSsrSnapshot } from "@/lib/billing/pricing-ssr-snapshot";
import { APP_SUBTITLE } from "@/lib/product-copy";

/** Server-rendered plan honesty — visible in initial HTML for tests and no-JS users. */
export async function PricingStaticShell({
  checkout,
  snap: snapProp,
}: {
  checkout?: string | string[] | null;
  snap?: PricingSsrSnapshot;
}) {
  const snap = snapProp ?? (await getPricingSsrSnapshot(checkout));

  return (
    <section
      data-pricing-ssr
      data-billing-state={snap.billingState}
      className="mt-2 rounded-2xl border border-white/10 bg-white/[0.02] px-4 py-5 sm:px-5"
      aria-label="Plans overview"
    >
      <p className="text-xs uppercase tracking-[0.2em] text-violet-200">{APP_SUBTITLE}</p>
      <h1 className="mt-2 text-2xl font-semibold tracking-tight text-white sm:text-3xl">
        Plans for your voice archive
      </h1>
      <div className="mt-4 grid gap-3 sm:grid-cols-2">
        <div data-pricing-plan="free" className="rounded-xl border border-white/10 p-3">
          <p className="text-lg font-medium text-zinc-100">Free</p>
          <p className="mt-1 text-sm text-zinc-300">
            £0 <span className="text-muted">/ forever</span>
          </p>
        </div>
        <div data-pricing-plan="pro" className="rounded-xl border border-violet-400/25 p-3">
          <p className="text-lg font-medium text-zinc-100">Pro</p>
          <p className="mt-1 text-sm text-zinc-300">{snap.proPriceLabel}</p>
          <p className="mt-2 text-xs text-muted" data-stripe-checkout-line>
            {snap.stripeCheckoutLine}
          </p>
        </div>
      </div>
      <p className="mt-4 text-xs leading-relaxed text-muted" data-checkout-availability>
        {snap.billingLive
          ? "Checkout available when signed in — billing handled by Stripe."
          : "Checkout unavailable — Stripe env not configured on this server."}
      </p>
      {snap.checkoutQuery === "cancel" ? (
        <p className="mt-3 text-sm text-zinc-300" data-checkout-cancel>
          Checkout canceled — no charge. Your archive is unchanged.
        </p>
      ) : null}
      {snap.checkoutQuery === "success" && snap.billingLive ? (
        <p className="mt-3 text-sm text-emerald-200/90" data-checkout-success>
          Checkout complete — Pro entitlements sync from the server when your subscription is
          active.
        </p>
      ) : null}
    </section>
  );
}
