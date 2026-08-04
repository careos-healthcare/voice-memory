import "server-only";

import {
  REVENUECAT_LEGACY_GRANDFATHERED_PRODUCT_IDS,
  REVENUECAT_PRO_ENTITLEMENT_IDS,
} from "@/lib/server/monetization-policy";

export { REVENUECAT_PRO_ENTITLEMENT_IDS };

export const REVENUECAT_CACHE_TTL_MS = 2 * 60 * 1000;
export const REVENUECAT_REQUEST_TIMEOUT_MS = 5_000;

export type RevenueCatVerification =
  | {
      status: "verified";
      active: boolean;
      source: "revenuecat" | "cache";
      checkedAt: number;
      periodStart: string | null;
      periodEnd: string | null;
      lifetime: boolean;
    }
  | {
      status: "unavailable";
      reason: "configuration" | "timeout" | "upstream" | "malformed";
    };

type FetchLike = typeof fetch;
type CacheEntry = {
  active: boolean;
  checkedAt: number;
  expiresAt: number;
  periodStart: string | null;
  periodEnd: string | null;
  lifetime: boolean;
};

const cache = new Map<string, CacheEntry>();
const inFlight = new Map<string, Promise<RevenueCatVerification>>();
let fetchImpl: FetchLike = globalThis.fetch;
let nowImpl = () => Date.now();

function cacheKey(appUserId: string, requiredIds: readonly string[]): string {
  return `${appUserId}\u0000${[...new Set(requiredIds)].sort().join("\u0000")}`;
}

function activeFromPayload(
  payload: unknown,
  requiredIds: readonly string[],
  now: number,
): {
  active: boolean;
  periodStart: string | null;
  periodEnd: string | null;
  lifetime: boolean;
} | null {
  if (!payload || typeof payload !== "object") return null;
  const subscriber = (payload as { subscriber?: unknown }).subscriber;
  if (!subscriber || typeof subscriber !== "object") return null;
  const entitlements = (subscriber as { entitlements?: unknown }).entitlements;
  if (!entitlements || typeof entitlements !== "object" || Array.isArray(entitlements)) {
    return null;
  }
  const subscriptions = (subscriber as { subscriptions?: unknown }).subscriptions;
  const verifiedLifetimeProduct = Boolean(
    subscriptions &&
      typeof subscriptions === "object" &&
      !Array.isArray(subscriptions) &&
      Object.entries(subscriptions).some(
        ([productId, raw]) =>
          REVENUECAT_LEGACY_GRANDFATHERED_PRODUCT_IDS.some(
            (candidate) => candidate === productId,
          ) &&
          raw !== null &&
          typeof raw === "object" &&
          (raw as { expires_date?: unknown }).expires_date === null,
      ),
  );

  for (const id of requiredIds) {
    const entitlement = (entitlements as Record<string, unknown>)[id];
    if (entitlement === undefined) continue;
    if (
      !entitlement ||
      typeof entitlement !== "object" ||
      Array.isArray(entitlement)
    ) {
      return null;
    }
    const expiresDate = (entitlement as { expires_date?: unknown }).expires_date;
    const purchaseDate = (entitlement as { purchase_date?: unknown }).purchase_date;
    const periodStart =
      typeof purchaseDate === "string" && Number.isFinite(Date.parse(purchaseDate))
        ? new Date(purchaseDate).toISOString()
        : null;
    if (expiresDate === null) {
      if (!verifiedLifetimeProduct) return null;
      return {
        active: true,
        periodStart,
        periodEnd: null,
        lifetime: verifiedLifetimeProduct,
      };
    }
    if (typeof expiresDate !== "string") continue;
    const expiresAt = Date.parse(expiresDate);
    if (Number.isFinite(expiresAt) && expiresAt > now) {
      return {
        active: true,
        periodStart,
        periodEnd: new Date(expiresAt).toISOString(),
        lifetime: false,
      };
    }
  }
  return { active: false, periodStart: null, periodEnd: null, lifetime: false };
}

async function queryRevenueCat(
  appUserId: string,
  requiredIds: readonly string[],
  key: string,
): Promise<RevenueCatVerification> {
  const secret = process.env.REVENUECAT_SECRET_API_KEY?.trim();
  if (!secret) return { status: "unavailable", reason: "configuration" };

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), REVENUECAT_REQUEST_TIMEOUT_MS);
  try {
    const response = await fetchImpl(
      `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(appUserId)}`,
      {
        method: "GET",
        headers: {
          Authorization: `Bearer ${secret}`,
          Accept: "application/json",
        },
        cache: "no-store",
        signal: controller.signal,
      },
    );

    let resolved: ReturnType<typeof activeFromPayload>;
    if (response.status === 404) {
      resolved = {
        active: false,
        periodStart: null,
        periodEnd: null,
        lifetime: false,
      };
    } else if (!response.ok) {
      return { status: "unavailable", reason: "upstream" };
    } else {
      let payload: unknown;
      try {
        payload = await response.json();
      } catch {
        return { status: "unavailable", reason: "malformed" };
      }
      resolved = activeFromPayload(payload, requiredIds, nowImpl());
      if (resolved === null) return { status: "unavailable", reason: "malformed" };
    }

    const checkedAt = nowImpl();
    cache.set(key, {
      active: resolved.active,
      checkedAt,
      expiresAt: checkedAt + REVENUECAT_CACHE_TTL_MS,
      periodStart: resolved.periodStart,
      periodEnd: resolved.periodEnd,
      lifetime: resolved.lifetime,
    });
    return {
      status: "verified",
      active: resolved.active,
      source: "revenuecat",
      checkedAt,
      periodStart: resolved.periodStart,
      periodEnd: resolved.periodEnd,
      lifetime: resolved.lifetime,
    };
  } catch (error) {
    return {
      status: "unavailable",
      reason:
        controller.signal.aborted ||
        (error instanceof Error && error.name === "AbortError")
          ? "timeout"
          : "upstream",
    };
  } finally {
    clearTimeout(timeout);
  }
}

async function verifyRevenueCatEntitlementInternal(
  appUserId: string,
  requiredIds: readonly string[],
  bypassCache: boolean,
): Promise<RevenueCatVerification> {
  const key = cacheKey(appUserId, requiredIds);
  const cached = cache.get(key);
  if (!bypassCache && cached && nowImpl() < cached.expiresAt) {
    return {
      status: "verified",
      active: cached.active,
      source: "cache",
      checkedAt: cached.checkedAt,
      periodStart: cached.periodStart,
      periodEnd: cached.periodEnd,
      lifetime: cached.lifetime,
    };
  }
  if (cached && nowImpl() >= cached.expiresAt) cache.delete(key);

  const existing = inFlight.get(key);
  if (existing) return existing;

  const lookup = queryRevenueCat(appUserId, requiredIds, key).then((result) => {
    if (result.status === "unavailable") {
      const fallback = cache.get(key);
      if (fallback && nowImpl() < fallback.expiresAt) {
        return {
          status: "verified" as const,
          active: fallback.active,
          source: "cache" as const,
          checkedAt: fallback.checkedAt,
          periodStart: fallback.periodStart,
          periodEnd: fallback.periodEnd,
          lifetime: fallback.lifetime,
        };
      }
    }
    return result;
  });
  inFlight.set(key, lookup);
  try {
    return await lookup;
  } finally {
    if (inFlight.get(key) === lookup) inFlight.delete(key);
  }
}

export async function verifyRevenueCatEntitlement(
  appUserId: string,
  requiredIds: readonly string[] = REVENUECAT_PRO_ENTITLEMENT_IDS,
): Promise<RevenueCatVerification> {
  return verifyRevenueCatEntitlementInternal(appUserId, requiredIds, false);
}

export async function __verifyRevenueCatEntitlementFreshForTests(
  appUserId: string,
  requiredIds: readonly string[] = REVENUECAT_PRO_ENTITLEMENT_IDS,
): Promise<RevenueCatVerification> {
  return verifyRevenueCatEntitlementInternal(appUserId, requiredIds, true);
}

export function __resetRevenueCatVerifierForTests(): void {
  cache.clear();
  inFlight.clear();
  fetchImpl = globalThis.fetch;
  nowImpl = () => Date.now();
}

export function __setRevenueCatVerifierForTests(options: {
  fetch?: FetchLike;
  now?: () => number;
}): void {
  if (options.fetch) fetchImpl = options.fetch;
  if (options.now) nowImpl = options.now;
}
