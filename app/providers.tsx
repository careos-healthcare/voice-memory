"use client";

import { AccountProvider } from "@/components/providers/AccountProvider";
import { StorageBootstrap } from "@/components/providers/StorageBootstrap";

export function AppProviders({ children }: { children: React.ReactNode }) {
  return (
    <AccountProvider>
      <StorageBootstrap />
      {children}
    </AccountProvider>
  );
}
