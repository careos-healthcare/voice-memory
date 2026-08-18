"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import { OrganicReferralPanel } from "@/components/internal/OrganicReferralPanel";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { buildOrganicReferralReport } from "@/lib/internal/organic-referral-report";
import type { OrganicReferralReport } from "@/types/organic-referral";

export default function OrganicReferralPage() {
  const [report, setReport] = useState<OrganicReferralReport | null>(null);

  const refresh = () => setReport(buildOrganicReferralReport());

  useEffect(() => {
    refresh();
  }, []);

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-5xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <header className="mt-2 flex items-start justify-between gap-4">
          <div>
            <p className="text-xs uppercase tracking-[0.2em] text-sky-300/80">Retention</p>
            <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
              Organic referral
            </h1>
            <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
              Whether users naturally want to tell someone about ArchiveMe — not marketing
              referrals or invite systems. Shown occasionally after five reflections, a strong
              reaction, and at least one Discover visit.
            </p>
          </div>
          <Button type="button" variant="ghost" size="sm" onClick={refresh}>
            <RefreshCw className="h-4 w-4" />
            Refresh
          </Button>
        </header>

        <div className="mt-6">{report ? <OrganicReferralPanel report={report} /> : null}</div>

        <div className="mt-10 flex flex-wrap gap-3 text-sm">
          <Link href="/internal/retention-discovery" className="text-violet-300 hover:text-violet-200">
            Retention discovery →
          </Link>
          <Link href="/internal/archive-attachment" className="text-violet-300 hover:text-violet-200">
            Archive attachment →
          </Link>
        </div>
      </div>
    </div>
  );
}
