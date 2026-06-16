"use client";

import { useState } from "react";
import Link from "next/link";

import { QuietShareCardPreview } from "@/components/sharing/QuietShareCard";
import { SiteFooter } from "@/components/SiteFooter";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { MotionPageTitle } from "@/components/motion/MotionPage";
import { STATIC_QUIET_SHARE_LINES } from "@/lib/sharing/quiet-sharing";
import { trackCreatorPreviewComplete } from "@/lib/sharing/share-observation";
import { ENCRYPTED_SYNC_COPY } from "@/lib/sync/copy";
import { ARCHIVE_PERMANENCE_COPY } from "@/lib/archive/copy";
import { PRIVATE_BY_DEFAULT_LINE } from "@/lib/trust-copy";
import type { QuietShareCard } from "@/types/sharing";

const STEPS = [
  {
    title: "Record a reflection",
    body: "Speak when something is on your mind. Nothing to perform — just your voice, kept privately.",
  },
  {
    title: "Return to an older entry",
    body: "Revisit something from weeks ago. The app notices when you sound different, or when a thread keeps returning.",
  },
  {
    title: "Before and now",
    body: "Sometimes the payoff is a quiet contrast — what you said then, and what you hear now.",
  },
  {
    title: "Privacy first",
    body: PRIVATE_BY_DEFAULT_LINE,
  },
  {
    title: "Your archive, yours",
    body: ARCHIVE_PERMANENCE_COPY.takeWithYou,
  },
  {
    title: "Export and sync",
    body: `${ENCRYPTED_SYNC_COPY.encryptedBeforeLeave} ${ENCRYPTED_SYNC_COPY.archiveNotServer}`,
  },
] as const;

const PREVIEW_CARD: QuietShareCard = {
  id: "creator-preview-example",
  line: STATIC_QUIET_SHARE_LINES[0],
  beforeLabel: "Before",
  nowLabel: "Now",
  source: "before_now",
};

export default function CreatorPreviewPage() {
  const [step, setStep] = useState(0);
  const [done, setDone] = useState(false);

  const current = STEPS[step];
  const isLast = step >= STEPS.length - 1;

  const finish = () => {
    trackCreatorPreviewComplete();
    setDone(true);
  };

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-2xl px-4 pb-24 sm:px-6">
        <SiteHeader />
        <MotionPageTitle title="Creator preview" />

        <div className="mt-16 space-y-10">
          <p className="text-sm leading-relaxed text-zinc-500">
            A two-minute walkthrough of the emotional payoff — not features, not coaching.
          </p>

          {done ? (
            <div className="space-y-6">
              <p className="text-[15px] leading-[1.75] text-zinc-300/95">
                That is the feeling ArchiveMe is built around — temporal, reflective, and private.
              </p>
              <div className="max-w-sm">
                <QuietShareCardPreview card={PREVIEW_CARD} />
              </div>
              <div className="flex flex-wrap gap-3">
                <Button asChild>
                  <Link href="/">Try it</Link>
                </Button>
                <Button asChild variant="ghost" className="text-zinc-500">
                  <Link href="/invite">Share the invite link</Link>
                </Button>
              </div>
            </div>
          ) : (
            <div className="space-y-8">
              <div>
                <p className="text-xs uppercase tracking-[0.18em] text-zinc-600">
                  Step {step + 1} of {STEPS.length}
                </p>
                <h2 className="mt-3 text-lg font-normal text-zinc-200">{current.title}</h2>
                <p className="mt-3 text-sm leading-relaxed text-zinc-400">{current.body}</p>
              </div>

              {step === 2 ? (
                <div className="max-w-sm">
                  <QuietShareCardPreview card={PREVIEW_CARD} />
                </div>
              ) : null}

              <div className="flex flex-wrap gap-2">
                {!isLast ? (
                  <Button type="button" size="sm" variant="secondary" onClick={() => setStep((s) => s + 1)}>
                    Next
                  </Button>
                ) : (
                  <Button type="button" size="sm" onClick={finish}>
                    Done
                  </Button>
                )}
                <Button type="button" size="sm" variant="ghost" className="text-zinc-600" onClick={finish}>
                  Skip to end
                </Button>
              </div>
            </div>
          )}
        </div>

        <SiteFooter />
      </div>
    </div>
  );
}
