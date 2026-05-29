"use client";

import { useEffect } from "react";

import { hydrateServerFeedbackSummary } from "@/lib/resurfacing/merged-feedback-client";

/** Loads privacy-safe server feedback summary for signed-in users. */
export function ResurfacingFeedbackHydrate() {
  useEffect(() => {
    void hydrateServerFeedbackSummary();
  }, []);
  return null;
}
