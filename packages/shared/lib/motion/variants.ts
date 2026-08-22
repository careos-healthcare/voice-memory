import type { Variants } from "framer-motion";

import { MOTION } from "@/lib/motion/tokens";

export const fadeUp: Variants = {
  hidden: { opacity: 0, y: MOTION.offset.page },
  visible: {
    opacity: 1,
    y: 0,
    transition: { duration: MOTION.duration.page, ease: MOTION.ease },
  },
};

export const fadeIn: Variants = {
  hidden: { opacity: 0 },
  visible: {
    opacity: 1,
    transition: { duration: MOTION.duration.fade, ease: MOTION.ease },
  },
};

export const noteContainer: Variants = {
  hidden: {},
  visible: {
    transition: { staggerChildren: MOTION.stagger.list, delayChildren: 0.05 },
  },
};

export const noteReveal: Variants = {
  hidden: { opacity: 0, y: MOTION.offset.note },
  visible: (delay: number) => ({
    opacity: 1,
    y: 0,
    transition: {
      duration: MOTION.duration.note,
      ease: MOTION.ease,
      delay,
    },
  }),
};

export const presenceFade: Variants = {
  initial: { opacity: 0, y: MOTION.offset.subtle },
  animate: {
    opacity: 1,
    y: 0,
    transition: { duration: MOTION.duration.presence, ease: MOTION.ease },
  },
  exit: {
    opacity: 0,
    y: -MOTION.offset.subtle,
    transition: { duration: MOTION.duration.presence * 0.85, ease: MOTION.ease },
  },
};
