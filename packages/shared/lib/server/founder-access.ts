import "server-only";

import { cookies } from "next/headers";

export const INTERNAL_ACCESS_COOKIE = "vm_debug";
const DEBUG_COOKIE = INTERNAL_ACCESS_COOKIE;

export function debugAccessToken(): string | null {
  return process.env.DEBUG_ACCESS_TOKEN?.trim() || null;
}

export function isDemoEnabledInProduction(): boolean {
  return process.env.VOICEMEMORY_ENABLE_DEMO === "true";
}

export async function hasFounderDebugCookie(): Promise<boolean> {
  const token = debugAccessToken();
  if (!token) return false;
  const cookieStore = await cookies();
  return cookieStore.get(DEBUG_COOKIE)?.value === token;
}

export function founderEmails(): Set<string> {
  const raw = process.env.VOICEMEMORY_FOUNDER_EMAILS?.trim();
  if (!raw) return new Set();
  return new Set(
    raw
      .split(",")
      .map((e) => e.trim().toLowerCase())
      .filter(Boolean),
  );
}

export function isFounderEmail(email: string): boolean {
  const set = founderEmails();
  if (set.size === 0) return false;
  return set.has(email.trim().toLowerCase());
}
