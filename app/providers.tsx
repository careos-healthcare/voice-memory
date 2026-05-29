"use client";

import { NativeBootstrap } from "@/components/mobile/NativeBootstrap";
import { PwaBootstrap } from "@/components/mobile/PwaBootstrap";
import { OnboardingNavigationTracker } from "@/components/onboarding/OnboardingNavigationTracker";
import { ResurfacingFeedbackHydrate } from "@/components/resurfacing/ResurfacingFeedbackHydrate";
import { AccountProvider } from "@/components/providers/AccountProvider";
import { StorageBootstrap } from "@/components/providers/StorageBootstrap";
import { VisualToneProvider } from "@/components/providers/VisualToneProvider";

export function AppProviders({ children }: { children: React.ReactNode }) {
  return (
    <AccountProvider>
      <VisualToneProvider>
        <NativeBootstrap />
        <PwaBootstrap />
        <StorageBootstrap />
        <ResurfacingFeedbackHydrate />
        <OnboardingNavigationTracker />
        {children}
      </VisualToneProvider>
    </AccountProvider>
  );
}
