import Link from "next/link";

import { ProductSimplificationPanel } from "@/archived-components/_archived/internal/ProductSimplificationPanel";
import { SiteHeader } from "@/components/SiteHeader";

export default function ProductSimplificationPage() {
  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-5xl px-4 pb-20 sm:px-6">
        <SiteHeader />
        <header className="mt-2">
          <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Internal</p>
          <h1 className="mt-2 text-3xl font-semibold text-white">Product simplification v1</h1>
          <p className="mt-2 text-sm text-zinc-400">
            Archive-first UX — routes and engines unchanged.
          </p>
        </header>
        <div className="mt-8">
          <ProductSimplificationPanel />
        </div>
        <Link href="/internal/founder-test" className="mt-8 inline-block text-sm text-violet-300">
          Founder test →
        </Link>
      </div>
    </div>
  );
}
