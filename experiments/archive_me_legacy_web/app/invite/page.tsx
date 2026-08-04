"use client";

import { useEffect } from "react";
import Link from "next/link";

import { SiteFooter } from "@/components/SiteFooter";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { MotionPageTitle } from "@/components/motion/MotionPage";
import { trackInviteOpen } from "@/lib/sharing/share-observation";
import { PRIVATE_BY_DEFAULT_LINE } from "@/lib/trust-copy";

const INVITE_LINES = [
  "Someone shared this with me.",
  "It felt more personal than taking notes.",
  "It remembers things I forgot I said.",
] as const;

export default function InvitePage() {
  useEffect(() => {
    trackInviteOpen(
      typeof window !== "undefined"
        ? new URLSearchParams(window.location.search).get("from") ?? undefined
        : undefined,
    );
  }, []);

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-2xl px-4 pb-24 sm:px-6">
        <SiteHeader />
        <MotionPageTitle title="A quiet invitation" />

        <div className="mt-16 space-y-10">
          <p className="text-sm leading-relaxed text-zinc-400">
            ArchiveMe is in early testing. If someone you trust shared it with you, you can try it
            privately — no account required to start.
          </p>

          <ul className="space-y-6">
            {INVITE_LINES.map((line) => (
              <li key={line} className="text-[15px] leading-[1.75] text-zinc-300/95">
                {line}
              </li>
            ))}
          </ul>

          <p className="text-sm leading-relaxed text-zinc-500">{PRIVATE_BY_DEFAULT_LINE}</p>

          <div className="flex flex-wrap gap-3 pt-2">
            <Button asChild>
              <Link href="/">Try it quietly</Link>
            </Button>
            <Button asChild variant="ghost" className="text-zinc-500">
              <Link href="/creator-preview">See how it works</Link>
            </Button>
          </div>

          <p className="text-xs leading-relaxed text-zinc-600">
            No referral counts. No rewards. Just a private place to hear yourself again.
          </p>
        </div>

        <SiteFooter />
      </div>
    </div>
  );
}
