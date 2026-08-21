import { PricingPageClient } from "@/app/pricing/PricingPageClient";
import { getPricingSsrSnapshot } from "@/lib/billing/pricing-ssr-snapshot";
import { PricingStaticShell } from "@/archived-components/_archived/pricing/PricingStaticShell";
import { PrimaryMain } from "@/components/layout/PrimaryMain";
import { SiteHeader } from "@/components/SiteHeader";

export default async function PricingPage({
  searchParams,
}: {
  searchParams: Promise<{ checkout?: string }>;
}) {
  const params = await searchParams;
  const pricingSnap = await getPricingSsrSnapshot(params.checkout);

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-20 sm:px-6">
        <SiteHeader />
        <PrimaryMain>
        <PricingStaticShell checkout={params.checkout} snap={pricingSnap} />
        <PricingPageClient
          initialBillingLive={pricingSnap.billingLive}
          initialProPriceLabel={pricingSnap.proPriceLabel}
          initialStripeCheckoutLine={pricingSnap.stripeCheckoutLine}
        />
        </PrimaryMain>
      </div>
    </div>
  );
}
