import "server-only";

/**
 * FOUNDER_MODE=true enables founder/internal tooling.
 * When unset or false, /internal routes are hidden from everyone.
 */
export function isFounderModeEnabled(): boolean {
  return process.env.FOUNDER_MODE === "true";
}
