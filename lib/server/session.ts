import "server-only";

import { cookies } from "next/headers";

import {
  SESSION_COOKIE,
  signSessionToken,
  verifySessionToken,
} from "@/lib/server/auth-crypto";
import { getUserById } from "@/lib/server/auth-store";
import {
  persistSessionPostgres,
  revokeSessionPostgres,
  sessionExistsPostgres,
} from "@/lib/server/auth-store-postgres";
import { shouldUsePostgresStorage } from "@/lib/server/db";
import type { StoredUser } from "@/lib/server/auth-storage";

export interface ServerSession {
  userId: string;
  email: string;
}

export async function getServerSession(): Promise<ServerSession | null> {
  const cookieStore = await cookies();
  const token = cookieStore.get(SESSION_COOKIE)?.value;
  if (!token) return null;

  const payload = verifySessionToken(token);
  if (!payload) return null;

  if (shouldUsePostgresStorage()) {
    const active = await sessionExistsPostgres(token);
    if (!active) return null;
  }

  const user = await getUserById(payload.userId);
  if (!user) return null;

  return { userId: user.id, email: user.email };
}

export async function persistSessionForUser(
  token: string,
  user: StoredUser,
): Promise<void> {
  if (!shouldUsePostgresStorage()) return;
  await persistSessionPostgres(token, user);
}

export async function revokeServerSession(token: string): Promise<void> {
  if (!shouldUsePostgresStorage()) return;
  await revokeSessionPostgres(token);
}

export function buildSessionCookie(token: string): {
  name: string;
  value: string;
  httpOnly: true;
  sameSite: "lax";
  secure: boolean;
  path: "/";
  maxAge: number;
} {
  return {
    name: SESSION_COOKIE,
    value: token,
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
    path: "/",
    maxAge: 60 * 60 * 24 * 30,
  };
}

export function clearSessionCookie(): {
  name: string;
  value: string;
  httpOnly: true;
  sameSite: "lax";
  secure: boolean;
  path: "/";
  maxAge: 0;
} {
  return {
    name: SESSION_COOKIE,
    value: "",
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
    path: "/",
    maxAge: 0,
  };
}

export function createSessionTokenForUser(user: { id: string; email: string }): string {
  return signSessionToken({ userId: user.id, email: user.email });
}
