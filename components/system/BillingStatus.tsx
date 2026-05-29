"use client";

import { useEffect, useState } from "react";

import { isProPreviewAllowed } from "@/lib/billing/billing-state";
import { useBillingPublicConfig } from "@/lib/billing/use-billing-public-config";
import {
  getEffectiveTierId,
  getTierSnapshot,
  refreshServerEntitlements,
} from "@/lib/entitlement/entitlements";
import { cn } from "@/lib/utils";

import { StatusBadge } from "./StatusBadge";
import { TrustNotice } from "./TrustNotice";

export function BillingStatus({ className }: { className?: string }) {
  const { billingLive } = useBillingPublicConfig();
  const [refreshing, setRefreshing] = useState(false);
  const [tier, setTier] = useState<"free" | "pro">("free");
  const [paidServer, setPaidServer] = useState(false);
  const [previewOnly, setPreviewOnly] = useState(false);

  const applySnapshot = () => {
    const snap = getTierSnapshot();
    const id = getEffectiveTierId();
    setTier(id);
    setPaidServer(billingLive && id === "pro" && !snap.previewMode);
    setPreviewOnly(snap.previewMode && id === "pro");
  };

  useEffect(() => {
    applySnapshot();
    if (billingLive) {
      void refreshServerEntitlements().then(applySnapshot);
    }
  }, [billingLive]);

  return (
    <div className={cn("space-y-3", className)}>
      <div className="flex flex-wrap items-center gap-2">
        <span className="text-sm font-medium text-zinc-200">Your plan</span>
        {paidServer ? (
          <StatusBadge tone="pro">Pro — paid</StatusBadge>
        ) : previewOnly ? (
          <StatusBadge tone="warning">Pro preview (local)</StatusBadge>
        ) : (
          <StatusBadge tone="neutral">Free</StatusBadge>
        )}
        {!billingLive ? (
          <StatusBadge tone="success">Checkout available</StatusBadge>
        ) : null}
      </div>
      {paidServer ? (
        <p className="text-xs text-zinc-500">
          Entitlements are backed by your Stripe subscription on this account.
        </p>
      ) : previewOnly ? (
        <p className="text-xs text-amber-200/80">
          Local preview only — not a paid subscription. Upgrade when checkout is enabled.
        </p>
      ) : billingLive ? (
        <p className="text-xs text-zinc-500">Upgrade anytime. Cancel in Stripe when you are subscribed.</p>
      ) : (
        <p className="text-xs text-zinc-500">
          Checkout is available when signed in — billing handled by Stripe.
        </p>
      )}
      {billingLive && refreshing ? (
        <p className="text-xs text-zinc-600" role="status">
          Refreshing entitlements…
        </p>
      ) : null}
      <TrustNotice>
        Secure Stripe checkout. VoiceMemory does not store your card. Cancel anytime from your Stripe
        customer portal when subscribed.
      </TrustNotice>
      {billingLive ? (
        <button
          type="button"
          className="text-xs text-violet-300 underline-offset-2 hover:underline"
          onClick={() => {
            setRefreshing(true);
            void refreshServerEntitlements().finally(() => {
              applySnapshot();
              setRefreshing(false);
            });
          }}
        >
          Refresh plan status
        </button>
      ) : null}
    </div>
  );
}
