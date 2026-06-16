import { trackLocalEvent } from "@/lib/local-analytics";

export const ACTIVATION_NEXT_REFLECTION_EVENT = "activation_next_reflection_clicked";

export function trackActivationNextReflectionClicked(surface: string): void {
  trackLocalEvent(ACTIVATION_NEXT_REFLECTION_EVENT, { surface });
}
