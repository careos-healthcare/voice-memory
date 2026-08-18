import manifest from "@/lib/server/active-api-routes-manifest.json";

export interface GuardedRouteSpec {
  routeFile: string;
  guard: "guardOpenAiRoute" | "guardAttestRoute" | "session";
}

export const GUARDED_OPENAI_API_ROUTES = manifest.guardedOpenAi as readonly GuardedRouteSpec[];
export const GUARDED_ATTEST_API_ROUTES = manifest.guardedAttest as readonly GuardedRouteSpec[];
export const ACTIVE_API_ROUTE_FILES = manifest.activeApiRouteFiles as readonly string[];
export const API_GUARD_SUPPORT_FILES = manifest.apiGuardSupportFiles as readonly string[];
export const CAPTURE_ATTEST_CLIENT_FILE = manifest.captureAttestClientFile;
export const SECURITY_RESPONSE_HEADERS_NOTES = manifest.securityResponseHeadersNotes;
