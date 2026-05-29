import { webPathFromDeepLink } from "@/lib/mobile/deep-links";
import { isNativeWrapper } from "@/lib/mobile/platform";
import { setNativePreference } from "@/lib/mobile/secure-storage";

/**
 * Register Capacitor App URL listeners (client-only).
 * Navigates the WebView to the matched path on the loaded origin.
 */
export async function registerCapacitorDeepLinks(): Promise<() => void> {
  if (!isNativeWrapper()) return () => {};

  try {
    const { App } = await import("@capacitor/app");
    const sub = await App.addListener("appUrlOpen", async (event) => {
      const webPath = webPathFromDeepLink(event.url);
      if (!webPath) return;
      await setNativePreference("last_deep_link_path", webPath);
      if (typeof window !== "undefined") {
        window.location.assign(webPath);
      }
    });
    const launch = await App.getLaunchUrl();
    if (launch?.url) {
      const webPath = webPathFromDeepLink(launch.url);
      if (webPath && typeof window !== "undefined") {
        window.location.assign(webPath);
      }
    }
    return () => {
      void sub.remove();
    };
  } catch {
    return () => {};
  }
}
