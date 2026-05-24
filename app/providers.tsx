"use client";

import { AccountProvider } from "@/components/providers/AccountProvider";
import { StorageBootstrap } from "@/components/providers/StorageBootstrap";
import { VisualToneProvider } from "@/components/providers/VisualToneProvider";

export function AppProviders({ children }: { children: React.ReactNode }) {
  return (
    <AccountProvider>
      <VisualToneProvider>
        <StorageBootstrap />
        {children}
      </VisualToneProvider>
    </AccountProvider>
  );
}
