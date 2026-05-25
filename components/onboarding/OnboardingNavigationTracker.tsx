"use client";

import { useEffect } from "react";
import { usePathname } from "next/navigation";

import {
  inferFlowProgressFromAppState,
  markFirstSessionStarted,
} from "@/lib/onboarding/first-session-flow";
import { recordOnboardingPageView } from "@/lib/onboarding/confusion-signals";
import { recordComprehensionSession } from "@/lib/onboarding/calm-comprehension";

export function OnboardingNavigationTracker() {
  const pathname = usePathname();

  useEffect(() => {
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
