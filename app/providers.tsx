"use client";

import { AccountProvider } from "@/components/providers/AccountProvider";

export function AppProviders({ children }: { children: React.ReactNode }) {
  return <AccountProvider>{children}</AccountProvider>;
}
