import { PricingPageClient } from "@/app/pricing/PricingPageClient";
import { PricingStaticShell } from "@/components/pricing/PricingStaticShell";
import { PrimaryMain } from "@/components/layout/PrimaryMain";
import { SiteHeader } from "@/components/SiteHeader";

export default function PricingPage() {
  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-20 sm:px-6">
        <SiteHeader />
        <PrimaryMain>
          <PricingStaticShell />
          <PricingPageClient />
        </PrimaryMain>
      </div>
    </div>
  );
}
