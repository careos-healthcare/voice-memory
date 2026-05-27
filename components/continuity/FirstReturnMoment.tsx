"use client";

import { motion } from "framer-motion";
import Link from "next/link";
import { useEffect, useState } from "react";

import {
  recordFirstReturnOpened,
  recordFirstReturnShown,
} from "@/lib/continuity/first-return-observation";
import { pickFirstReturnMoment } from "@/lib/continuity/first-return-moment";
import type { FirstReturnMomentData } from "@/lib/continuity/first-return-moment";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";

const fade = {
  initial: { opacity: 0, y: 6 },
  animate: { opacity: 1, y: 0 },
  transition: { duration: 0.45, ease: [0.22, 1, 0.36, 1] as const },
};

export function FirstReturnMoment({
  entries: entriesProp,
  className,
  presentation = "card",
  trackShown = false,
}: {
  entries?: JournalEntry[];
  className?: string;
  /** Home uses borderless quote-first layout; journal/memory keep a soft frame. */
  presentation?: "card" | "quiet";
  /** Record local first-return metrics (homepage). */
  trackShown?: boolean;
}) {
  const [moment, setMoment] = useState<FirstReturnMomentData | null>(null);

  useEffect(() => {
    const id = requestAnimationFrame(() => {
      const list = entriesProp ?? getMemoryEligibleEntries();
      setMoment(pickFirstReturnMoment(list));
    });
    return () => cancelAnimationFrame(id);
  }, [entriesProp]);

  useEffect(() => {
    if (!moment || !trackShown) return;
    recordFirstReturnShown();
  }, [moment, trackShown]);

  if (!moment) return null;

  const href = moment.relatedEntryIds[0]
    ? `/entry/${moment.relatedEntryIds[0]}`
    : null;

  const quiet = presentation === "quiet";

  const body = (
    <div
      className={`space-y-3 ${quiet ? "px-0 py-2 text-center" : "space-y-4 px-1 py-1 text-center sm:text-left"}`}
    >
      <p
        className={
          quiet
            ? "font-serif text-[1.75rem] leading-[1.25] tracking-tight text-zinc-50 sm:text-[2.15rem]"
            : "font-serif text-2xl leading-snug tracking-tight text-zinc-100 sm:text-[1.65rem]"
        }
      >
        {moment.quote}
      </p>
      <p
        className={
          quiet
            ? "text-sm leading-relaxed text-zinc-400"
            : "text-sm leading-relaxed text-violet-200/85"
        }
      >
        {moment.subline}
      </p>
      <p className="text-xs tracking-wide text-zinc-600">{moment.meta}</p>
    </div>
  );

  const shellClass = quiet
    ? className ?? ""
    : `rounded-2xl border border-violet-400/20 bg-gradient-to-b from-violet-500/[0.08] to-transparent px-6 py-10 sm:px-8 ${className ?? ""}`;

  const content = href ? (
    <Link
      href={href}
      className="block transition-opacity hover:opacity-95"
      onClick={() => recordFirstReturnOpened()}
    >
      {body}
    </Link>
  ) : (
    body
  );

  return (
    <motion.section
      initial={fade.initial}
      animate={fade.animate}
      transition={fade.transition}
      className={shellClass}
      aria-label="You said this before"
    >
      {content}
    </motion.section>
  );
}
