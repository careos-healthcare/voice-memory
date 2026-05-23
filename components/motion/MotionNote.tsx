"use client";

import { motion } from "framer-motion";

import { noteDelayForTone, type NoteMotionTone } from "@/lib/motion/tokens";
import { noteContainer, noteReveal } from "@/lib/motion/variants";
import { cn } from "@/lib/utils";

export function MotionNoteList({
  children,
  className,
}: {
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <motion.ul
      initial="hidden"
      animate="visible"
      variants={noteContainer}
      className={className}
    >
      {children}
    </motion.ul>
  );
}

export function MotionNoteItem({
  children,
  index = 0,
  tone = "default",
  className,
}: {
  children: React.ReactNode;
  index?: number;
  tone?: NoteMotionTone;
  className?: string;
}) {
  const breathe = tone === "resurfacing";

  return (
    <motion.li
      custom={noteDelayForTone(tone, index)}
      variants={noteReveal}
      className={cn(breathe ? "memory-breathe" : undefined, className)}
    >
      {children}
    </motion.li>
  );
}
