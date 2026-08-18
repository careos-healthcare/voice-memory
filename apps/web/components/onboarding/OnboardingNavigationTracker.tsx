"use client";

import { useEffect } from "react";
import { usePathname } from "next/navigation";

import {
  inferFlowProgressFromAppState,
  markFirstSessionStarted,
} from "@/lib/onboarding/first-session-flow";
import { recordOnboardingPageView } from "@/lib/onboarding/confusion-signals";
import { recordComprehensionSession } from "@/lib/onboarding/calm-comprehension";
import { observeFunnelFirstVisit } from "@/lib/retention/first-week-funnel";
import { observeSessionDeviceContext } from "@/lib/behavior/observation";
import { markAppSessionStarted } from "@/lib/retention/session-retention";

export function OnboardingNavigationTracker() {
  const pathname = usePathname();

  useEffect(() => {
    observeFunnelFirstVisit();
    markAppSessionStarted();
    observeSessionDeviceContext();
    markFirstSessionStarted();
    recordComprehensionSession();
    inferFlowProgressFromAppState();
  }, []);

  useEffect(() => {
    if (!pathname) return;
    recordOnboardingPageView(pathname);
    inferFlowProgressFromAppState();
  }, [pathname]);

  return null;
}
