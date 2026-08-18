"use client";

import Link from "next/link";
import { ScanEye } from "lucide-react";

import { Card, CardContent } from "@/components/ui/card";
import { BLIND_SPOT_PAGE } from "@/lib/blind-spots/blind-spot-copy";

interface BlindSpotReviewCtaProps {
  className?: string;
}

export function BlindSpotReviewCta({ className }: BlindSpotReviewCtaProps) {
  return (
    <Card className={`border-white/5 bg-violet-950/10 ${className ?? ""}`}>
      <CardContent className="flex flex-col gap-4 p-5 sm:flex-row sm:items-center sm:justify-between">
        <div className="flex gap-3">
          <ScanEye className="mt-0.5 h-5 w-5 shrink-0 text-violet-300/90" aria-hidden />
          <div>
            <p className="text-sm font-medium text-zinc-200">{BLIND_SPOT_PAGE.ctaTitle}</p>
            <p className="mt-1 text-sm leading-relaxed text-zinc-500">
              {BLIND_SPOT_PAGE.ctaBody}
            </p>
          </div>
        </div>
        <Link
          href="/blind-spots"
          className="inline-flex shrink-0 items-center justify-center rounded-xl border border-violet-400/30 bg-violet-500/10 px-4 py-2.5 text-sm font-medium text-violet-100 transition hover:border-violet-400/50 hover:bg-violet-500/20"
        >
          {BLIND_SPOT_PAGE.ctaAction}
        </Link>
      </CardContent>
    </Card>
  );
}
