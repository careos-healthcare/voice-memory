export async function register() {
  /** Edge middleware must not load Node-only server modules (avoids /debug 500s). */
  if (process.env.NEXT_RUNTIME === "edge") {
    return;
  }

  const { validateProductionAuthEmailEnv } = await import("@/lib/server/env-check");
  const { assertProductionRuntimeReadiness } = await import(
    "@/lib/server/production-readiness"
  );
  const { logServerEvent } = await import("@/lib/server/structured-log");

  validateProductionAuthEmailEnv();
  try {
    assertProductionRuntimeReadiness();
    logServerEvent("production_startup", { ready: true });
  } catch (error) {
    logServerEvent("production_startup", {
      ready: false,
      error: error instanceof Error ? error.message : "unknown",
    });
    throw error;
  }
}
