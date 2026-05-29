"use client";

import { motion } from "framer-motion";

import { useReducedMotion } from "@/lib/hooks/use-reduced-motion";
import { pageMotionVariants } from "@/lib/motion/reduced-motion";
import { cn } from "@/lib/utils";

export function MotionPage({
  children,
  className,
}: {
  children: React.ReactNode;
  className?: string;
}) {
  const reduced = useReducedMotion();
  const Component = reduced ? "div" : motion.div;
  const props = reduced
    ? { className: cn(className) }
    : {
        initial: "hidden" as const,
        animate: "visible" as const,
        variants: pageMotionVariants(reduced),
        className: cn(className),
      };

  return <Component {...props}>{children}</Component>;
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
        <p className="text-xs tracking-[0.18em] text-muted">{eyebrow}</p>
      ) : null}
      <h1 className="mt-3 text-2xl font-normal tracking-tight text-zinc-100 sm:text-3xl">
        {title}
      </h1>
    </MotionPage>
  );
}
