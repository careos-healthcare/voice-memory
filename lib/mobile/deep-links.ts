/**
 * Deep link routes for Capacitor shell → hosted Next.js app.
 * Universal links (https) require server AASA/assetlinks — not configured yet.
 */

export const NATIVE_URL_SCHEME = "voicememory";

export type NativeDeepLinkKind = "auth" | "billing" | "app";

export interface ParsedNativeDeepLink {
  kind: NativeDeepLinkKind;
  /** Path + query to open on the web app origin, e.g. /pricing?checkout=success */
  webPath: string;
  raw: string;
}

const AUTH_PREFIXES = ["/auth", "/api/auth", "/sign-in", "/login"];
const BILLING_PREFIXES = ["/pricing", "/account", "/billing"];

export function parseNativeDeepLink(url: string): ParsedNativeDeepLink | null {
  if (!url?.trim()) return null;

  try {
    const parsed = url.includes("://")
      ? new URL(url)
      : new URL(`${NATIVE_URL_SCHEME}://${url.replace(/^\/*/, "")}`);

    const scheme = parsed.protocol.replace(":", "");
    if (scheme !== NATIVE_URL_SCHEME && !url.startsWith("https://") && !url.startsWith("http://")) {
      return null;
    }

    const path = `${parsed.pathname}${parsed.search}`;
    const webPath = path.startsWith("/") ? path : `/${path}`;

    if (AUTH_PREFIXES.some((p) => webPath.startsWith(p))) {
      return { kind: "auth", webPath, raw: url };
    }
    if (BILLING_PREFIXES.some((p) => webPath.startsWith(p))) {
      return { kind: "billing", webPath, raw: url };
    }
    return { kind: "app", webPath, raw: url };
  } catch {
    return null;
  }
}

export function webPathFromDeepLink(url: string): string | null {
  return parseNativeDeepLink(url)?.webPath ?? null;
}
