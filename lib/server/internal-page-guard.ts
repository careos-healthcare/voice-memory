import "server-only";

import { cookies, headers } from "next/headers";
import { notFound } from "next/navigation";

import {
  INTERNAL_ACCESS_COOKIE,
  debugAccessToken,
  isFounderEmail,
} from "@/lib/server/founder-access";
import {
  isDevelopmentRuntime,
  isInternalSurfaceEnabled,
} from "@/lib/server/internal-access";
import { getServerSession } from "@/lib/server/session";
import { logInternalAccessEvent } from "@/lib/server/internal-access-log";

/** Server-side gate for /internal/* pages — do not rely on middleware alone. */
export async function assertInternalPageAccess(): Promise<void> {
  const headerStore = await headers();
  const pathname = headerStore.get("x-vm-internal-path") ?? "/internal";
  const method = headerStore.get("x-vm-internal-method") ?? "GET";

  if (!isInternalSurfaceEnabled()) {
    await logInternalAccessEvent({
      pathname,
      method,
      outcome: "denied",
      detail: "internal_disabled",
      ipHash: headerStore.get("x-forwarded-for") ?? "unknown",
    });
    notFound();
  }

  const expected = debugAccessToken();
  if (!expected) {
    await logInternalAccessEvent({
      pathname,
      method,
      outcome: "denied",
      detail: "token_unconfigured",
      ipHash: headerStore.get("x-forwarded-for") ?? "unknown",
    });
    notFound();
  }

  const cookieStore = await cookies();
  const cookie = cookieStore.get(INTERNAL_ACCESS_COOKIE)?.value?.trim();
  if (cookie === expected) {
    await logInternalAccessEvent({
      pathname,
      method,
      outcome: "allowed",
      detail: "cookie",
      ipHash: headerStore.get("x-forwarded-for") ?? "unknown",
    });
    return;
  }

  const session = await getServerSession();
  if (session?.email && isFounderEmail(session.email)) {
    await logInternalAccessEvent({
      pathname,
      method,
      outcome: "allowed",
      detail: "founder_session",
      ipHash: headerStore.get("x-forwarded-for") ?? "unknown",
    });
    return;
  }

  if (isDevelopmentRuntime() && process.env.VOICEMEMORY_DEV_INTERNAL_BYPASS === "1") {
    await logInternalAccessEvent({
      pathname,
      method,
      outcome: "allowed",
      detail: "dev_bypass",
      ipHash: headerStore.get("x-forwarded-for") ?? "unknown",
    });
    return;
  }

  await logInternalAccessEvent({
    pathname,
    method,
    outcome: "denied",
    detail: "unauthorized",
    ipHash: headerStore.get("x-forwarded-for") ?? "unknown",
  });
  notFound();
}
