import { getOrCreateDeviceId } from "@/lib/sync/device-id";

let attestPromise: Promise<boolean> | null = null;

/** Obtain session or signed capture cookie before OpenAI routes. */
export async function ensureCaptureAttested(): Promise<boolean> {
  if (typeof window === "undefined") return false;

  if (attestPromise) return attestPromise;

  attestPromise = (async () => {
    try {
      const sessionRes = await fetch("/api/auth/session", { credentials: "include" });
      if (sessionRes.ok) {
        const sessionJson = (await sessionRes.json()) as { session?: unknown };
        if (sessionJson.session) return true;
      }

      const deviceId = getOrCreateDeviceId();
      const res = await fetch("/api/capture/attest", {
        method: "POST",
        credentials: "include",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ deviceId }),
      });

      if (!res.ok) {
        attestPromise = null;
        return false;
      }

      const json = (await res.json()) as { ok?: boolean; token?: string };
      if (json.token) {
        sessionStorage.setItem("voicememory_capture_token", json.token);
      }
      return Boolean(json.ok);
    } catch {
      attestPromise = null;
      return false;
    }
  })();

  return attestPromise;
}

export function captureAuthHeaders(): Record<string, string> {
  if (typeof window === "undefined") return {};
  const token = sessionStorage.getItem("voicememory_capture_token");
  if (!token) return {};
  return { "x-vm-capture-token": token };
}

export function resetCaptureAttestCache(): void {
  attestPromise = null;
}
