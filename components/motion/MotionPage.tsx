"use client";

import { motion } from "framer-motion";

import { fadeUp } from "@/lib/motion/variants";
import { cn } from "@/lib/utils";

export function MotionPage({
  children,
  className,
}: {
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <motion.div
      initial="hidden"
      animate="visible"
      variants={fadeUp}
      className={cn(className)}
    >
      {children}
    </motion.div>
  );
}

export function MotionPageTitle({
  eyebrow,
  title,
  className,
}: {
  eyebrow?: string;
  title: string;
  className?: string;
}) {
  return (
    <MotionPage className={cn("mt-2", className)}>
      {eyebrow ? (
        <p className="text-xs tracking-[0.18em] text-zinc-600">{eyebrow}</p>
      ) : null}
      <h1 className="mt-3 text-2xl font-normal tracking-tight text-zinc-100 sm:text-3xl">
        {title}
      </h1>
    </MotionPage>
  );
}
