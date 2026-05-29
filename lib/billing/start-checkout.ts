/**
 * Start Stripe Checkout — server creates session; price id never exposed to client.
 */

export type StartCheckoutResult =
  | { ok: true; url: string }
  | { ok: false; code: string; message: string };

export async function startStripeCheckout(): Promise<StartCheckoutResult> {
  const res = await fetch("/api/billing/checkout", {
    method: "POST",
    credentials: "include",
  });

  const body = (await res.json().catch(() => ({}))) as {
    url?: string;
    error?: string;
    code?: string;
  };

  if (!res.ok) {
    return {
      ok: false,
      code: body.code ?? "CHECKOUT_FAILED",
      message: body.error ?? "Could not start checkout.",
    };
  }

  if (!body.url) {
    return {
      ok: false,
      code: "CHECKOUT_FAILED",
      message: "Checkout session missing URL.",
    };
  }

  return { ok: true, url: body.url };
}
