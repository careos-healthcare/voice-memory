"use client";

import { motion } from "framer-motion";
import type { ReactNode } from "react";

import {
  ARCHIVE_CARD_FADE,
  ARCHIVE_CONFIDENCE_PULSE,
  ARCHIVE_FADE_IN,
  ARCHIVE_MOVEMENT_FADE,
  archiveStaggerDelay,
} from "@/lib/archive/archive-polish-motion";
import { useReducedMotion } from "@/lib/hooks/use-reduced-motion";
import { cn } from "@/lib/utils";

import type { ArchiveTransitionMode } from "@/types/archive-transition";

type ArchiveTransitionProps = {
  children: ReactNode;
  mode?: ArchiveTransitionMode;
  className?: string;
  /** Stagger index for timeline / list items */
  staggerIndex?: number;
  /** Re-animate when this key changes (e.g. confidence value) */
  motionKey?: string | number;
  testId?: string;
};

export type { ArchiveTransitionMode };

export function ArchiveTransition({
  children,
  mode = "fade",
  className,
  staggerIndex = 0,
  motionKey,
  testId,
}: ArchiveTransitionProps) {
  const reduced = useReducedMotion();

  if (reduced) {
    return (
      <div className={className} data-testid={testId}>
        {children}
      </div>
    );
  }

  const preset =
    mode === "card"
      ? ARCHIVE_CARD_FADE
      : mode === "movement"
        ? ARCHIVE_MOVEMENT_FADE
        : mode === "confidence"
          ? ARCHIVE_CONFIDENCE_PULSE
          : ARCHIVE_FADE_IN;

  const delay =
    mode === "timeline" ? archiveStaggerDelay(staggerIndex) : staggerIndex * 0.04;

  return (
    <motion.div
      key={motionKey}
      initial={preset.initial}
      animate={preset.animate}
      transition={{
        ...preset.transition,
        delay,
      }}
      className={cn(className)}
      data-testid={testId}
    >
      {children}
    </motion.div>
  );
}

/** Animated confidence percentage in command center. */
export function ArchiveAnimatedConfidence({
  value,
  className,
}: {
  value: number;
  className?: string;
}) {
  const reduced = useReducedMotion();

  if (reduced) {
    return (
      <span className={cn("text-lg font-semibold text-violet-100 tabular-nums", className)}>
        {value}%
      </span>
    );
  }

  return (
    <ArchiveTransition mode="confidence" motionKey={value} className={className}>
      <span className="text-lg font-semibold text-violet-100 tabular-nums">{value}%</span>
    </ArchiveTransition>
  );
}
