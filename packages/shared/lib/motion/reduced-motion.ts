import type { Transition, Variants } from "framer-motion";

import { fadeUp, presenceFade } from "@/lib/motion/variants";

/** Instant variants when user prefers reduced motion. */
export const reducedFadeUp: Variants = {
  hidden: { opacity: 1, y: 0 },
  visible: { opacity: 1, y: 0 },
};

export const reducedPresenceFade: Variants = {
  initial: { opacity: 1, y: 0 },
  animate: { opacity: 1, y: 0 },
  exit: { opacity: 1, y: 0 },
};

export function motionVariants(
  full: Variants,
  reduced: Variants,
  isReduced: boolean,
): Variants {
  return isReduced ? reduced : full;
}

export function motionTransition(
  full: Transition,
  isReduced: boolean,
): Transition {
  return isReduced ? { duration: 0 } : full;
}

export function pageMotionVariants(isReduced: boolean): Variants {
  return motionVariants(fadeUp, reducedFadeUp, isReduced);
}

export function presenceMotionVariants(isReduced: boolean): Variants {
  return motionVariants(presenceFade, reducedPresenceFade, isReduced);
}
