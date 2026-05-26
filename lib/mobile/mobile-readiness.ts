import { getPaymentStackAudit } from "@/lib/entitlement/payment-stack";
import {
  auditIndexedDbUsage,
  auditLocalStoragePressure,
} from "@/lib/mobile/storage-audit";
import {
  isNativeWrapper,
  isPWA,
  supportsBackgroundAudio,
  supportsPush,
} from "@/lib/mobile/platform";
import { readMicrophonePermission } from "@/lib/mobile/microphone";
import { getNotificationSchedulerStatus } from "@/lib/notifications/scheduler";

export type ReadinessStatus = "ready" | "partial" | "blocked" | "unknown";

export interface MobileReadinessCheck {
  id: string;
  label: string;
  status: ReadinessStatus;
  detail: string;
}

export interface MobileReadinessReport {
  generatedAt: string;
  runtime: string;
  checks: MobileReadinessCheck[];
  warnings: string[];
}

function statusFromBool(ok: boolean, partial = false): ReadinessStatus {
  if (ok) return "ready";
  if (partial) return "partial";
  return "blocked";
}

export async function buildMobileReadinessReport(): Promise<MobileReadinessReport> {
  const warnings: string[] = [];
  const checks: MobileReadinessCheck[] = [];

  const mic = await readMicrophonePermission();
  checks.push({
    id: "microphone",
    label: "Microphone permission",
    status: mic === "denied" ? "blocked" : mic === "granted" ? "ready" : "partial",
    detail: mic,
  });

  const storage = auditLocalStoragePressure();
  checks.push({
    id: "local_storage",
    label: "localStorage pressure",
    status:
      storage.pressure === "high"
        ? "blocked"
        : storage.pressure === "moderate"
          ? "partial"
          : "ready",
    detail: `${storage.keyCount} keys · ~${Math.round(storage.estimatedBytes / 1024)} KB`,
  });

  const idb = auditIndexedDbUsage();
  checks.push({
    id: "indexeddb",
    label: "IndexedDB (audio)",
    status: statusFromBool(idb.available),
    detail: idb.note,
  });

  const offline =
    typeof window !== "undefined" &&
    ("serviceWorker" in navigator || isNativeWrapper());
  checks.push({
    id: "offline_shell",
    label: "Offline shell",
    status: offline ? "partial" : "blocked",
    detail: offline
      ? "Service worker registers quiet offline fallback — app requires network for first load"
      : "No service worker support",
  });

  const installable =
    typeof window !== "undefined" && ("BeforeInstallPromptEvent" in window || isPWA());
  checks.push({
    id: "installability",
    label: "Installability (PWA)",
    status: isPWA() ? "ready" : installable ? "partial" : "unknown",
    detail: isPWA()
      ? "Running in standalone display mode"
      : installable
        ? "beforeinstallprompt may be available on Chromium"
        : "Install prompt not yet observed",
  });

  checks.push({
    id: "viewport",
    label: "Viewport & safe areas",
    status: "ready",
    detail: "device-width viewport, theme-color, safe-area CSS utilities in globals",
  });

  checks.push({
    id: "touch_targets",
    label: "Touch targets",
    status: "partial",
    detail: "Primary buttons use min 44px height; audit entry/recorder on real devices",
  });

  checks.push({
    id: "hydration",
    label: "Hydration / render risks",
    status: "partial",
    detail:
      "Heavy presentation deferred via heavyReady; open-loop continuity idle; runtime read/write split",
  });

  const pushStatus = getNotificationSchedulerStatus();
  checks.push({
    id: "push_readiness",
    label: "Push architecture",
    status: supportsPush() ? "partial" : "unknown",
    detail: `${pushStatus.mode} scheduler · ${pushStatus.registeredTriggers} quiet triggers defined`,
  });

  checks.push({
    id: "background_audio",
    label: "Background audio",
    status: supportsBackgroundAudio() ? "partial" : "unknown",
    detail: supportsBackgroundAudio()
      ? "Media Session API available on web; native wrapper TBD"
      : "Limited on mobile web",
  });

  const payment = getPaymentStackAudit();
  checks.push({
    id: "stripe_mobile",
    label: "Stripe mobile compatibility",
    status: payment.checkoutImplemented ? "partial" : "unknown",
    detail: payment.checkoutImplemented
      ? "Use Stripe Checkout in browser / in-app browser — avoid WebView cookie issues"
      : "Checkout not wired — no mobile payment risk yet",
  });

  if (storage.pressure !== "low") {
    warnings.push("localStorage approaching mobile quota — prefer IndexedDB for large blobs");
  }
  if (mic === "denied") {
    warnings.push("Microphone denied — core recording path blocked");
  }

  return {
    generatedAt: new Date().toISOString(),
    runtime: isNativeWrapper() ? "capacitor" : isPWA() ? "pwa" : "web",
    checks,
    warnings,
  };
}
