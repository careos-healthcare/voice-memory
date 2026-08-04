import { createHmac } from "node:crypto";

const ACTIVE_VERSION_ENV = "VOICEMEMORY_UNIT_ECONOMICS_HMAC_ACTIVE_VERSION";
const KEY_ENV_PREFIX = "VOICEMEMORY_UNIT_ECONOMICS_HMAC_KEY_V";
const DEV_FALLBACK_ENV = "VOICEMEMORY_UNIT_ECONOMICS_ALLOW_DEV_FALLBACK";
const DEV_FALLBACK_KEY = Buffer.from(
  "voicememory-unit-economics-explicit-development-fallback-key-v1",
  "utf8",
);

export type EconomicsSubjectKind = "user" | "device" | "anonymous";

interface VersionedKey {
  version: number;
  key: Buffer;
}

function parseVersion(value: string | undefined): number | null {
  if (!value?.trim() || !/^[1-9][0-9]*$/.test(value.trim())) return null;
  return Number(value);
}

function decodeKey(value: string, name: string): Buffer {
  const encoded = value.trim();
  if (!/^[A-Za-z0-9+/_-]+={0,2}$/.test(encoded)) {
    throw new Error(`${name} must be base64 or base64url.`);
  }
  const key = Buffer.from(encoded, "base64");
  if (key.length < 32) throw new Error(`${name} must decode to at least 32 bytes.`);
  return key;
}

function configuredKeys(): VersionedKey[] {
  const keys: VersionedKey[] = [];
  for (const [name, value] of Object.entries(process.env)) {
    if (!name.startsWith(KEY_ENV_PREFIX) || !value) continue;
    const version = parseVersion(name.slice(KEY_ENV_PREFIX.length));
    if (version === null) continue;
    keys.push({ version, key: decodeKey(value, name) });
  }
  keys.sort((a, b) => a.version - b.version);
  return keys;
}

function resolveKeys(): { active: VersionedKey; all: VersionedKey[] } {
  const activeVersion = parseVersion(process.env[ACTIVE_VERSION_ENV]);
  const all = configuredKeys();
  if (activeVersion !== null) {
    const active = all.find((item) => item.version === activeVersion);
    if (!active) throw new Error(`${KEY_ENV_PREFIX}${activeVersion} is required.`);
    return { active, all };
  }

  if (
    process.env.NODE_ENV !== "production" &&
    process.env[DEV_FALLBACK_ENV]?.trim().toLowerCase() === "true"
  ) {
    const fallback = { version: 1, key: DEV_FALLBACK_KEY };
    const rotationKeys = all.some((item) => item.version === fallback.version)
      ? all
      : [fallback, ...all].sort((a, b) => a.version - b.version);
    return { active: fallback, all: rotationKeys };
  }

  throw new Error(`${ACTIVE_VERSION_ENV} is required for unit economics.`);
}

function digest(versionedKey: VersionedKey, domain: string, parts: readonly string[]): string {
  const hmac = createHmac("sha256", versionedKey.key);
  hmac.update(`voicememory/unit-economics/${domain}/v1\0`, "utf8");
  for (const part of parts) {
    const bytes = Buffer.from(part, "utf8");
    hmac.update(`${bytes.length}:`, "utf8");
    hmac.update(bytes);
    hmac.update("\0", "utf8");
  }
  return hmac.digest("base64url");
}

export function createEconomicsSubjectKey(
  kind: EconomicsSubjectKind,
  rawIdentifier: string,
): string {
  if (!rawIdentifier) throw new Error("A non-empty subject identifier is required.");
  const { active } = resolveKeys();
  return `ue:v${active.version}:${digest(active, `subject/${kind}`, [rawIdentifier])}`;
}

export function createEconomicsSubjectKeysForRotation(
  kind: EconomicsSubjectKind,
  rawIdentifier: string,
): string[] {
  if (!rawIdentifier) throw new Error("A non-empty subject identifier is required.");
  return resolveKeys().all.map(
    (item) => `ue:v${item.version}:${digest(item, `subject/${kind}`, [rawIdentifier])}`,
  );
}

export function createEconomicsEventKey(...stableParts: readonly string[]): string {
  if (stableParts.length === 0 || stableParts.some((part) => !part)) {
    throw new Error("Event key parts must be non-empty.");
  }
  const { active } = resolveKeys();
  return `uee:v${active.version}:${digest(active, "event", stableParts)}`;
}

/** Turns an external idempotency value into an opaque event-key component. */
export function createEconomicsOpaqueEventPart(value: string): string {
  if (!value) throw new Error("A non-empty idempotency value is required.");
  const { active } = resolveKeys();
  return digest(active, "event-part", [value]);
}

export function createEconomicsBreachKey(...stableParts: readonly string[]): string {
  if (stableParts.length === 0 || stableParts.some((part) => !part)) {
    throw new Error("Breach key parts must be non-empty.");
  }
  const { active } = resolveKeys();
  return `ueb:v${active.version}:${digest(active, "breach", stableParts)}`;
}

export function createEconomicsBreachDedupKey(...stableParts: readonly string[]): string {
  if (stableParts.length === 0 || stableParts.some((part) => !part)) {
    throw new Error("Breach dedup key parts must be non-empty.");
  }
  const { active } = resolveKeys();
  return `ued:v${active.version}:${digest(active, "breach-dedup", stableParts)}`;
}

export function configuredEconomicsHmacVersions(): number[] {
  return resolveKeys().all.map((item) => item.version);
}
