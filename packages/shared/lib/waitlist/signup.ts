import { randomUUID } from "node:crypto";

import { MARKETING_SITE_URL, WAITLIST_EMAIL_FROM } from "../site/marketing-site";

export const WAITLIST_IP_MAX = 5;
export const WAITLIST_IP_WINDOW_MS = 60 * 60 * 1000;

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

type IpBucket = { count: number; resetAt: number };

const ipBuckets = new Map<string, IpBucket>();

export type WaitlistInsertResult = "created" | "duplicate";

export interface WaitlistStore {
  insert(email: string, unsubscribeToken: string): Promise<WaitlistInsertResult>;
}

export interface WaitlistSignupResult {
  status: number;
  body: { ok: true; success: true } | { ok: false; error: string };
}

export function normalizeWaitlistEmail(value: string): string {
  return value.trim().toLowerCase();
}

export function isValidWaitlistEmail(value: string): boolean {
  const email = normalizeWaitlistEmail(value);
  return email.length <= 320 && EMAIL_PATTERN.test(email);
}

export function resetWaitlistIpBucketsForTest(): void {
  ipBuckets.clear();
}

/** In-memory per-IP burst limit. Keys are raw IPs and are not written to the waitlist table. */
export function allowWaitlistIp(ip: string, nowMs: number): boolean {
  if (ipBuckets.size > 10_000) ipBuckets.clear();
  const bucket = ipBuckets.get(ip);
  if (!bucket || nowMs > bucket.resetAt) {
    ipBuckets.set(ip, { count: 1, resetAt: nowMs + WAITLIST_IP_WINDOW_MS });
    return true;
  }
  bucket.count += 1;
  return bucket.count <= WAITLIST_IP_MAX;
}

export function waitlistUnsubscribeUrl(token: string): string {
  return `${MARKETING_SITE_URL}/api/waitlist/unsubscribe?token=${encodeURIComponent(token)}`;
}

export function waitlistFromAddress(env: NodeJS.ProcessEnv = process.env): string {
  const configured = env.EMAIL_FROM?.trim();
  return configured && configured.length > 0 ? configured : WAITLIST_EMAIL_FROM;
}

export function clientIpFromRequest(request: Request): string {
  const forwarded = request.headers.get("x-forwarded-for");
  const first = forwarded?.split(",")[0]?.trim();
  if (first) return first;
  return request.headers.get("x-real-ip")?.trim() || "unknown";
}

export async function signupForWaitlist(input: {
  email: string;
  ip: string;
  nowMs?: number;
  honeypot?: string;
  store: WaitlistStore;
  sendConfirmation?: (email: string, unsubscribeUrl: string) => Promise<void>;
}): Promise<WaitlistSignupResult> {
  if ((input.honeypot ?? "").trim().length > 0) {
    return { status: 200, body: { ok: true, success: true } };
  }
  if (!isValidWaitlistEmail(input.email)) {
    return { status: 400, body: { ok: false, error: "Enter a valid email address." } };
  }
  if (!allowWaitlistIp(input.ip, input.nowMs ?? Date.now())) {
    return { status: 429, body: { ok: false, error: "Too many sign-ups from this network. Try again later." } };
  }

  const email = normalizeWaitlistEmail(input.email);
  const token = randomUUID();
  const result = await input.store.insert(email, token);
  if (result === "created") {
    try {
      await input.sendConfirmation?.(email, waitlistUnsubscribeUrl(token));
    } catch (error) {
      console.error("Waitlist confirmation email failed.", error);
    }
  }
  return { status: 200, body: { ok: true, success: true } };
}
