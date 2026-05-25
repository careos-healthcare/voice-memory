"use client";

import { OnboardingNavigationTracker } from "@/components/onboarding/OnboardingNavigationTracker";
import { AccountProvider } from "@/components/providers/AccountProvider";
import { StorageBootstrap } from "@/components/providers/StorageBootstrap";
import { VisualToneProvider } from "@/components/providers/VisualToneProvider";

export function AppProviders({ children }: { children: React.ReactNode }) {
  return (
    <AccountProvider>
      <VisualToneProvider>
        <StorageBootstrap />
        <OnboardingNavigationTracker />
        {children}
      </VisualToneProvider>
    </AccountProvider>
  );
}
