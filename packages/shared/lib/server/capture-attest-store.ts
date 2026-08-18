import { captureTokenMaxUses } from "@/lib/capture/capture-token";
import { dbQuery, shouldUsePostgresStorage } from "@/lib/server/db";

const globalAttest = globalThis as typeof globalThis & {
  __vmCaptureAttest?: Map<
    string,
    { deviceId: string; ipHash: string; uaHash: string; useCount: number; maxUses: number }
  >;
};

function memoryMap() {
  if (!globalAttest.__vmCaptureAttest) globalAttest.__vmCaptureAttest = new Map();
  return globalAttest.__vmCaptureAttest;
}

export async function registerCaptureAttestation(input: {
  jti: string;
  deviceId: string;
  ipHash: string;
  uaHash: string;
}): Promise<void> {
  const maxUses = captureTokenMaxUses();
  if (shouldUsePostgresStorage()) {
    await dbQuery(
      `INSERT INTO capture_attestations (token_jti, device_id, ip_hash, ua_hash, use_count, max_uses)
       VALUES ($1, $2, $3, $4, 0, $5)
       ON CONFLICT (token_jti) DO NOTHING`,
      [input.jti, input.deviceId, input.ipHash, input.uaHash, maxUses],
    );
    return;
  }
  memoryMap().set(input.jti, {
    deviceId: input.deviceId,
    ipHash: input.ipHash,
    uaHash: input.uaHash,
    useCount: 0,
    maxUses,
  });
}

export async function consumeCaptureAttestation(
  jti: string,
  binding: { ipHash: string; uaHash: string },
): Promise<{ ok: true } | { ok: false; reason: "unknown" | "binding" | "exhausted" }> {
  if (shouldUsePostgresStorage()) {
    const row = await dbQuery<{
      ip_hash: string;
      ua_hash: string;
      use_count: number;
      max_uses: number;
    }>(
      `SELECT ip_hash, ua_hash, use_count, max_uses FROM capture_attestations WHERE token_jti = $1`,
      [jti],
    );
    const record = row.rows[0];
    if (!record) return { ok: false, reason: "unknown" };
    if (record.ip_hash !== binding.ipHash || record.ua_hash !== binding.uaHash) {
      return { ok: false, reason: "binding" };
    }
    if (record.use_count >= record.max_uses) {
      return { ok: false, reason: "exhausted" };
    }
    const updated = await dbQuery(
      `UPDATE capture_attestations
       SET use_count = use_count + 1
       WHERE token_jti = $1 AND use_count < max_uses`,
      [jti],
    );
    if ((updated.rowCount ?? 0) === 0) return { ok: false, reason: "exhausted" };
    return { ok: true };
  }

  const record = memoryMap().get(jti);
  if (!record) return { ok: false, reason: "unknown" };
  if (record.ipHash !== binding.ipHash || record.uaHash !== binding.uaHash) {
    return { ok: false, reason: "binding" };
  }
  if (record.useCount >= record.maxUses) return { ok: false, reason: "exhausted" };
  record.useCount += 1;
  return { ok: true };
}
