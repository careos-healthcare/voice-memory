"use client";

import { NativeBootstrap } from "@/components/mobile/NativeBootstrap";
import { PwaBootstrap } from "@/components/mobile/PwaBootstrap";
import { PushVerificationBootstrap } from "@/components/notifications/PushVerificationBootstrap";
import { OnboardingNavigationTracker } from "@/components/onboarding/OnboardingNavigationTracker";
import { RetentionInstrumentation } from "@/components/retention/RetentionInstrumentation";
import { ResurfacingFeedbackHydrate } from "@/components/resurfacing/ResurfacingFeedbackHydrate";
import { AuthPromptProvider } from "@/components/auth/AuthPromptProvider";
import { AccountProvider } from "@/components/providers/AccountProvider";
import { StorageBootstrap } from "@/components/providers/StorageBootstrap";
import { VisualToneProvider } from "@/components/providers/VisualToneProvider";

export function AppProviders({ children }: { children: React.ReactNode }) {
  return (
    <AccountProvider>
      <AuthPromptProvider>
      <VisualToneProvider>
        <NativeBootstrap />
        <PwaBootstrap />
        <PushVerificationBootstrap />
        <StorageBootstrap />
        <ResurfacingFeedbackHydrate />
        <OnboardingNavigationTracker />
        <RetentionInstrumentation />
        {children}
      </VisualToneProvider>
      </AuthPromptProvider>
    </AccountProvider>
  );
}
