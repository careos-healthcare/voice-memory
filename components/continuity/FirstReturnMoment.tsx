"use client";

import { motion } from "framer-motion";
import Link from "next/link";
import { useEffect, useState } from "react";

import { MemoryConfidence } from "@/components/system/MemoryConfidence";
import { useReducedMotion } from "@/lib/hooks/use-reduced-motion";
import { presenceMotionVariants } from "@/lib/motion/reduced-motion";

import {
  recordFirstReturnOpened,
  recordFirstReturnShown,
} from "@/lib/continuity/first-return-observation";
import { pickFirstReturnMoment } from "@/lib/continuity/first-return-moment";
import type { FirstReturnMomentData } from "@/lib/continuity/first-return-moment";
import { recordResurfacingFeedback } from "@/lib/resurfacing/resurfacing-feedback";
import {
  recordResurfacingMetric,
  syncRerecordMetricFromFirstReturn,
} from "@/lib/resurfacing/resurfacing-metrics";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";

export function FirstReturnMoment({
  entries: entriesProp,
  className,
  presentation = "card",
  trackShown = false,
}: {
  entries?: JournalEntry[];
  className?: string;
  presentation?: "card" | "quiet";
  trackShown?: boolean;
}) {
  const [moment, setMoment] = useState<FirstReturnMomentData | null>(null);
  const [dismissed, setDismissed] = useState(false);
  const reducedMotion = useReducedMotion();

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
    syncRerecordMetricFromFirstReturn();
  }, [moment, trackShown]);

  if (!moment || dismissed) return null;

  const href = moment.relatedEntryIds[0]
    ? `/entry/${moment.relatedEntryIds[0]}`
    : null;

  const quiet = presentation === "quiet";

  const handleFeedback = (kind: Parameters<typeof recordResurfacingFeedback>[0]["kind"]) => {
    recordResurfacingFeedback({
      kind,
      quote: moment.quote,
      surface: "first_return",
    });
    if (kind !== "that_fits") setDismissed(true);
    if (kind === "that_fits") {
      recordResurfacingMetric("callback_fit_clicked", {
        phraseKey: moment.phraseKey,
      });
    }
  };

  const body = (
    <MemoryConfidence
      quote={moment.quote}
      subline={moment.subline}
      whySurfaced={moment.whySurfaced}
      confidenceLabel={moment.uncertain ? moment.meta : moment.meta}
      onFeedback={handleFeedback}
      className={quiet ? "px-0 py-2 text-center sm:text-center" : "text-center sm:text-left"}
    />
  );

  const shellClass = quiet
    ? className ?? ""
    : `rounded-2xl border border-violet-400/20 bg-gradient-to-b from-violet-500/[0.08] to-transparent px-6 py-10 sm:px-8 ${className ?? ""}`;

  const content = href ? (
    <Link
      href={href}
      className="block transition-opacity hover:opacity-95"
      onClick={() => {
        recordFirstReturnOpened();
        recordResurfacingMetric("related_memory_opened", {
          phraseKey: moment.phraseKey,
        });
      }}
    >
      {body}
    </Link>
  ) : (
    body
  );

  if (quiet) {
    return <div className={shellClass}>{content}</div>;
  }

  return (
    <motion.div
      className={shellClass}
      variants={presenceMotionVariants(reducedMotion)}
      initial="hidden"
      animate="visible"
    >
      {content}
    </motion.div>
  );
}
