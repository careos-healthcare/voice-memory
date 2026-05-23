const ONBOARDING_KEY = "voicememory_onboarding_dismissed";

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

export function isOnboardingDismissed(): boolean {
  if (!isBrowser()) return false;
  return localStorage.getItem(ONBOARDING_KEY) === "1";
}

export function dismissOnboarding(): void {
  if (!isBrowser()) return;
  localStorage.setItem(ONBOARDING_KEY, "1");
}

export function resetOnboarding(): void {
  if (!isBrowser()) return;
  localStorage.removeItem(ONBOARDING_KEY);
}
