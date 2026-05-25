const DEV = process.env.NODE_ENV !== "production";

/** Development-only sync diagnostics — never logs ciphertext or keys. */
export function syncWarn(message: string, meta?: Record<string, unknown>): void {
  if (!DEV) return;
  if (meta) {
    console.warn("[sync]", message, meta);
  } else {
    console.warn("[sync]", message);
  }
}
