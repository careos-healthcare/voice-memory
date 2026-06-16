import "server-only";

import type { TestPushTargetRoute } from "@/types/mobile-push";

type FcmMessaging = {
  send: (message: {
    token: string;
    notification: { title: string; body: string };
    data: Record<string, string>;
    android?: { priority: "high" };
    apns?: { payload: { aps: { sound: string } } };
  }) => Promise<string>;
};

let messaging: FcmMessaging | null | undefined;

function parseServiceAccount():
  | { project_id: string; client_email: string; private_key: string }
  | null {
  const json = process.env.FIREBASE_SERVICE_ACCOUNT_JSON?.trim();
  if (json) {
    try {
      return JSON.parse(json) as {
        project_id: string;
        client_email: string;
        private_key: string;
      };
    } catch {
      return null;
    }
  }
  const projectId = process.env.FIREBASE_PROJECT_ID?.trim();
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL?.trim();
  const privateKey = process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, "\n").trim();
  if (!projectId || !clientEmail || !privateKey) return null;
  return { project_id: projectId, client_email: clientEmail, private_key: privateKey };
}

export function isFcmConfigured(): boolean {
  return parseServiceAccount() !== null;
}

async function getMessaging(): Promise<FcmMessaging | null> {
  if (messaging !== undefined) return messaging;
  const account = parseServiceAccount();
  if (!account) {
    messaging = null;
    return null;
  }
  try {
    const admin = await import("firebase-admin");
    if (!admin.apps.length) {
      admin.initializeApp({
        credential: admin.credential.cert({
          projectId: account.project_id,
          clientEmail: account.client_email,
          privateKey: account.private_key,
        }),
      });
    }
    messaging = admin.messaging() as FcmMessaging;
    return messaging;
  } catch (err) {
    console.error("[FCM] init failed", err);
    messaging = null;
    return null;
  }
}

export async function sendFcmTestPush(params: {
  token: string;
  targetRoute: TestPushTargetRoute;
}): Promise<{ messageId: string }> {
  const fcm = await getMessaging();
  if (!fcm) {
    throw new Error("FCM_NOT_CONFIGURED");
  }

  const messageId = await fcm.send({
    token: params.token,
    notification: {
      title: "ArchiveMe",
      body: `Test push → ${params.targetRoute}`,
    },
    data: {
      route: params.targetRoute,
      type: "test_push",
      expectedRoute: params.targetRoute,
    },
    android: { priority: "high" },
    apns: {
      payload: {
        aps: { sound: "default" },
      },
    },
  });

  return { messageId };
}

export function isStaleTokenError(error: unknown): boolean {
  const msg = error instanceof Error ? error.message : String(error);
  return (
    msg.includes("registration-token-not-registered") ||
    msg.includes("invalid-registration-token") ||
    msg.includes("NOT_FOUND")
  );
}
