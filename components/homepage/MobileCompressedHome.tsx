"use client";

import { useState, type ReactNode } from "react";

import { Button } from "@/components/ui/button";
import {
  MOBILE_FIRST_RUN_PRIVACY,
  MOBILE_FIRST_RUN_TAGLINE,
} from "@/lib/mobile/mobile-first-run";
import { HOMEPAGE_CLARITY } from "@/lib/product-copy";

export function MobileCompressedHome({
  recorder,
}: {
  recorder: ReactNode;
}) {
  const [howOpen, setHowOpen] = useState(false);

  return (
    <div className="flex w-full max-w-md flex-col items-center text-center">
      <h1 className="text-sm font-medium text-zinc-200">VoiceMemory</h1>
      <p className="mt-3 text-base leading-relaxed text-zinc-300">{MOBILE_FIRST_RUN_TAGLINE}</p>
      <div className="mt-6 w-full">{recorder}</div>
      <p className="mt-8 max-w-xs text-xs leading-relaxed text-muted">
        {MOBILE_FIRST_RUN_PRIVACY}
      </p>
      <Button
        type="button"
        variant="ghost"
        size="sm"
        className="mt-4 text-muted hover:text-zinc-200"
        onClick={() => setHowOpen((open) => !open)}
        aria-expanded={howOpen}
      >
        {howOpen ? "Hide how it works" : "How it works"}
      </Button>
      {howOpen ? (
        <ul className="mt-4 max-w-sm space-y-2 text-left text-sm leading-relaxed text-zinc-500">
          <li>{HOMEPAGE_CLARITY.stepSpeak}</li>
          <li>{HOMEPAGE_CLARITY.stepRemember}</li>
          <li>{HOMEPAGE_CLARITY.stepReturn}</li>
        </ul>
      ) : null}
    </div>
  );
}
