import fs from "node:fs";
import path from "node:path";

import { flutterRoot, readFlutter } from "@/lib/mobile/flutter-repo";
import type {
  MobileIndependenceAudit,
  MobileIndependenceViolation,
  IndependenceViolationKind,
} from "@/types/mobile-first-class";

const WEB_ONLY_ROUTE_PATTERN =
  /['"`]\/(internal|founder-test|debug\/|api\/debug)[^'"`]*['"`]/i;

const DESKTOP_ONLY_COPY =
  /(use (the )?desktop|open (on|in) (a )?browser|sign in on web|web-only|desktop-only)/i;

function walkDartFiles(
  onFile: (rel: string, content: string) => void,
  dirRel = "lib",
): void {
  const root = path.join(flutterRoot(), dirRel);
  if (!fs.existsSync(root)) return;
  for (const ent of fs.readdirSync(root, { withFileTypes: true })) {
    const rel = path.join(dirRel, ent.name);
    if (ent.isDirectory()) walkDartFiles(onFile, rel);
    else if (ent.name.endsWith(".dart")) {
      onFile(rel, fs.readFileSync(path.join(flutterRoot(), rel), "utf8"));
    }
  }
}

function pushViolation(
  violations: MobileIndependenceViolation[],
  kind: IndependenceViolationKind,
  detail: string,
  file?: string,
): void {
  violations.push({ kind, detail, file });
}

/** Fail when mobile structurally depends on desktop/web-only paths. */
export function auditMobileIndependence(): MobileIndependenceAudit {
  const violations: MobileIndependenceViolation[] = [];
  const router = readFlutter("lib/router/app_router.dart");
  const pricing = readFlutter("lib/screens/pricing_screen.dart");
  const account = readFlutter("lib/screens/account_screen.dart");
  const settings = readFlutter("lib/screens/settings_screen.dart");

  if (WEB_ONLY_ROUTE_PATTERN.test(router)) {
    pushViolation(
      violations,
      "desktop_route",
      "app_router references internal/founder/debug web routes",
      "lib/router/app_router.dart",
    );
  }

  if (!readFlutter("lib/screens/settings_screen.dart").includes("SettingsScreen")) {
    pushViolation(
      violations,
      "desktop_only_settings",
      "No mobile /settings screen — settings would be web-only",
    );
  }

  if (!account.includes("sendAuthCode")) {
    pushViolation(
      violations,
      "desktop_only_auth",
      "Account screen missing in-app email auth — auth would require web",
      "lib/screens/account_screen.dart",
    );
  }

  const pubspec = readFlutter("pubspec.yaml");
  if (
    !pubspec.includes("purchases_flutter") &&
    pricing.includes("launchUrl") &&
    pricing.includes("LaunchMode.externalApplication")
  ) {
    pushViolation(
      violations,
      "browser_only_purchase",
      "Purchase path opens external browser (Stripe) with no native IAP — not independent store billing",
      "lib/screens/pricing_screen.dart",
    );
  }

  walkDartFiles((rel, content) => {
    if (WEB_ONLY_ROUTE_PATTERN.test(content) && !rel.includes("test")) {
      pushViolation(
        violations,
        "desktop_route",
        `${rel} references web-internal route`,
        rel,
      );
    }
    if (DESKTOP_ONLY_COPY.test(content)) {
      pushViolation(
        violations,
        "web_only_flow",
        `${rel} copy steers users to desktop/web`,
        rel,
      );
    }
    if (/import\s+['"]package:voice_memory\/web/.test(content)) {
      pushViolation(
        violations,
        "desktop_only_component",
        `${rel} imports web-only component package`,
        rel,
      );
    }
  });

  if (settings.includes("href=") || settings.includes("window.open")) {
    pushViolation(
      violations,
      "web_only_flow",
      "Settings uses browser-only navigation primitives",
      "lib/screens/settings_screen.dart",
    );
  }

  const independent = violations.length === 0;

  return {
    generatedAt: new Date().toISOString(),
    independent,
    violations,
  };
}
