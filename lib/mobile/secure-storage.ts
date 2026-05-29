/**
 * Native secure storage strategy (Capacitor Preferences).
 *
 * - Auth session: httpOnly cookies on the Next.js origin inside the WebView.
 *   Do NOT store session tokens in Preferences or localStorage on native.
 * - Preferences: non-sensitive UX flags only (install dismiss, onboarding hints).
 * - Journal/audio: existing IndexedDB + server sync — unchanged by native shell.
 */

import { isNativeWrapper } from "@/lib/mobile/platform";

const NATIVE_ONLY_PREFIX = "vm_native_pref_";

export type NativePreferenceKey =
  | "last_deep_link_path"
  | "mobile_shell_version_ack";

async function preferencesPlugin() {
  if (!isNativeWrapper()) return null;
  try {
    const { Preferences } = await import("@capacitor/preferences");
    return Preferences;
  } catch {
    return null;
  }
}

export async function setNativePreference(
  key: NativePreferenceKey,
  value: string,
): Promise<void> {
  const prefs = await preferencesPlugin();
  if (!prefs) return;
  await prefs.set({ key: `${NATIVE_ONLY_PREFIX}${key}`, value });
}

export async function getNativePreference(
  key: NativePreferenceKey,
): Promise<string | null> {
  const prefs = await preferencesPlugin();
  if (!prefs) return null;
  const { value } = await prefs.get({ key: `${NATIVE_ONLY_PREFIX}${key}` });
  return value ?? null;
}

export async function clearNativePreferences(): Promise<void> {
  const prefs = await preferencesPlugin();
  if (!prefs) return;
  const { keys } = await prefs.keys();
  for (const key of keys) {
    if (key.startsWith(NATIVE_ONLY_PREFIX)) {
      await prefs.remove({ key });
    }
  }
}

/** Documented boundary — never call for secrets. */
export function assertNotSecretStorage(field: string): void {
  const banned = ["token", "secret", "password", "session", "api_key", "stripe"];
  const lower = field.toLowerCase();
  if (banned.some((b) => lower.includes(b))) {
    throw new Error(`Refusing to store sensitive field in Preferences: ${field}`);
  }
}
