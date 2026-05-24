import "server-only";

import { cookies } from "next/headers";

import { SESSION_COOKIE, signSessionToken, verifySessionToken } from "@/lib/server/auth-crypto";
import { getUserById } from "@/lib/server/auth-store";

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

  const user = getUserById(payload.userId);
  if (!user) return null;

  return { userId: user.id, email: user.email };
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
