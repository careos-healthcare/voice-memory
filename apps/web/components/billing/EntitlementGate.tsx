"use client";

import type { ReactNode } from "react";

import { UpgradeCta } from "@/components/billing/UpgradeCta";
import {
  entitlementGateCopy,
  hasEntitlement,
} from "@/lib/entitlement/entitlements";
import type { EntitlementId } from "@/types/entitlement";
import type { UpgradeClickSource } from "@/lib/subscription";

interface EntitlementGateProps {
  entitlement: EntitlementId;
  source: UpgradeClickSource;
  children: ReactNode;
  /** When true, still render children if user already has loops/data from before downgrade. */
  allowExisting?: boolean;
  hasExisting?: boolean;
}

export function EntitlementGate({
  entitlement,
  source,
  children,
  allowExisting = false,
  hasExisting = false,
}: EntitlementGateProps) {
  if (hasEntitlement(entitlement)) return <>{children}</>;
  if (allowExisting && hasExisting) return <>{children}</>;

  const copy = entitlementGateCopy(entitlement);
  return (
    <UpgradeCta
      source={source}
      feature={copy.feature}
      headline={copy.title}
      description={copy.detail}
    />
  );
}
