"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";

import { SiteFooter } from "@/components/SiteFooter";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { MotionPageTitle } from "@/components/motion/MotionPage";
import { CreatorStoryBuilder } from "@/lib/distribution/creator-story-builder";
import { buildCreatorKit } from "@/lib/distribution/creator-kit";
import { trackCreatorKitOpened, trackCreatorStoryCopied } from "@/lib/distribution/distribution-events";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import type { CreatorStoryFormat } from "@/types/distribution";

function KitSection({ title, items }: { title: string; items: string[] }) {
  return (
    <section className="space-y-3">
      <h2 className="text-sm font-medium uppercase tracking-wide text-zinc-500">{title}</h2>
      <ol className="list-decimal space-y-2 pl-5 text-sm leading-relaxed text-zinc-300">
        {items.map((item, index) => (
          <li key={`${title}-${index}`}>{item}</li>
        ))}
      </ol>
    </section>
  );
}

export default function CreatorKitPage() {
  const hydrated = useClientHydrated();
  const kit = useMemo(() => (hydrated ? buildCreatorKit() : null), [hydrated]);
  const [format, setFormat] = useState<CreatorStoryFormat>("tiktok");

  useEffect(() => {
    if (hydrated) trackCreatorKitOpened();
  }, [hydrated]);

  const storyText = hydrated
    ? new CreatorStoryBuilder().export(format)
    : "";

  const copyStory = async () => {
    if (!storyText || typeof navigator === "undefined" || !navigator.clipboard) return;
    await navigator.clipboard.writeText(storyText);
    trackCreatorStoryCopied({ format });
  };

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-2xl px-4 pb-24 sm:px-6">
        <SiteHeader />
        <MotionPageTitle title="Creator kit" />

        <p className="mt-6 text-sm leading-relaxed text-zinc-500">
          Hooks, story templates, screenshot lines, and archive moments generated from your real
          archive events — not generic marketing copy.
        </p>

        {kit ? (
          <div className="mt-10 space-y-10">
            <KitSection title="10 hooks" items={kit.hooks} />
            <KitSection title="10 story templates" items={kit.storyTemplates} />
            <KitSection title="10 screenshot examples" items={kit.screenshotExamples} />
            <KitSection title="10 archive moments" items={kit.archiveMoments} />

            <section className="rounded-2xl border border-white/10 bg-zinc-900/40 px-4 py-4 space-y-3">
              <h2 className="text-sm font-medium text-zinc-200">Export story</h2>
              <div className="flex flex-wrap gap-2">
                {(["tiktok", "instagram", "shorts"] as const).map((f) => (
                  <Button
                    key={f}
                    type="button"
                    size="sm"
                    variant={format === f ? "secondary" : "ghost"}
                    onClick={() => setFormat(f)}
                  >
                    {f}
                  </Button>
                ))}
              </div>
              <pre className="whitespace-pre-wrap text-sm leading-relaxed text-zinc-400">
                {storyText}
              </pre>
              <Button type="button" size="sm" onClick={() => void copyStory()}>
                Copy story
              </Button>
            </section>
          </div>
        ) : (
          <p className="mt-10 text-sm text-zinc-600">
            Record a few moments and visit your archive to generate a personal creator kit.
          </p>
        )}

        <div className="mt-10">
          <Link href="/archive-belief" className="text-sm text-violet-300 hover:text-violet-200">
            Open archive →
          </Link>
        </div>

        <SiteFooter />
      </div>
    </div>
  );
}
