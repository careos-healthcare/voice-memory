export async function register() {
  const { validateProductionAuthEmailEnv } = await import("@/lib/server/env-check");
  validateProductionAuthEmailEnv();
}
