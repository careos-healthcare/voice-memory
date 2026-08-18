/**
 * Start Stripe Checkout — server creates session; price id never exposed to client.
 */

import { extractApiError } from "@/lib/sync/parse-response";

export type StartCheckoutResult =
  | { ok: true; url: string }
  | { ok: false; code: string; message: string };

export async function startStripeCheckout(): Promise<StartCheckoutResult> {
  const res = await fetch("/api/billing/checkout", {
    method: "POST",
    credentials: "include",
  });

  const body = (await res.json().catch(() => ({}))) as Record<string, unknown>;

  if (!res.ok) {
    const apiError = extractApiError(body);
    return {
      ok: false,
      code: apiError?.code ?? "CHECKOUT_FAILED",
      message: apiError?.message ?? "Could not start checkout.",
    };
  }

  const url = typeof body.url === "string" ? body.url : undefined;
  if (!url) {
    return {
      ok: false,
      code: "CHECKOUT_FAILED",
      message: "Checkout session missing URL.",
    };
  }

  return { ok: true, url };
}
