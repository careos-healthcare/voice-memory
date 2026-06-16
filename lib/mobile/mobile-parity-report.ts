import { readFlutter, flutterHasRoute, flutterHasScreenToken } from "@/lib/mobile/flutter-repo";
import type {
  MobileParityFeature,
  MobileParityReport,
  ParityFeatureId,
  ParityStatus,
} from "@/types/mobile-first-class";

const V1_REQUIRED: ParityFeatureId[] = [
  "belief",
  "evidence",
  "timeline",
  "trust",
  "reputation",
  "ownership",
  "survival",
  "accuracy",
  "contradictions",
  "activity",
  "export",
  "auth",
  "subscription",
];

type FeatureSpec = {
  id: ParityFeatureId;
  label: string;
  resolve: () => { status: ParityStatus; mobileSurface: string; notes: string[] };
};

function resolveFeatures(): MobileParityFeature[] {
  const archive = readFlutter("lib/screens/archive_belief_screen.dart");
  const router = readFlutter("lib/router/app_router.dart");
  const pubspec = readFlutter("pubspec.yaml");
  const pricing = readFlutter("lib/screens/pricing_screen.dart");

  const specs: FeatureSpec[] = [
    {
      id: "belief",
      label: "Belief",
      resolve: () => {
        if (!archive.includes("ArchiveBeliefScreen")) {
          return { status: "MISSING", mobileSurface: "—", notes: ["No archive belief home"] };
        }
        const complete =
          archive.includes("ArchiveBeliefHeaderMobile") &&
          archive.includes("living_archive_mobile");
        return {
          status: complete ? "COMPLETE" : "PARTIAL",
          mobileSurface: "/archive-belief",
          notes: complete
            ? ["Belief header + living archive stack"]
            : ["Archive route without full belief stack"],
        };
      },
    },
    {
      id: "evidence",
      label: "Evidence",
      resolve: () => {
        if (!archive.includes("EvidenceLockerCompact")) {
          return {
            status: readFlutter("lib/screens/journal_screen.dart").includes("JournalEntry")
              ? "PARTIAL"
              : "MISSING",
            mobileSurface: "journal",
            notes: ["Evidence locker not on archive home"],
          };
        }
        return {
          status: "COMPLETE",
          mobileSurface: "EvidenceLockerCompact on /archive-belief",
          notes: [],
        };
      },
    },
    {
      id: "timeline",
      label: "Timeline",
      resolve: () => {
        const updates = flutterHasRoute("/updates");
        const maturity = readFlutter("lib/features/archive_maturity/archive_maturity_engine.dart");
        if (!updates && !maturity.includes("timelineAgeDays")) {
          return { status: "MISSING", mobileSurface: "—", notes: [] };
        }
        return {
          status: updates && maturity.includes("timelineAgeDays") ? "PARTIAL" : "PARTIAL",
          mobileSurface: "/updates + local timeline age",
          notes: ["Simplified local timeline — not full web belief-change engine"],
        };
      },
    },
    {
      id: "trust",
      label: "Trust",
      resolve: () => {
        if (!archive.includes("ArchiveReputationCardMobile")) {
          return { status: "MISSING", mobileSurface: "—", notes: [] };
        }
        return {
          status: "PARTIAL",
          mobileSurface: "ArchiveReputationCardMobile",
          notes: ["Local reputation heuristics — not full web trust graph"],
        };
      },
    },
    {
      id: "reputation",
      label: "Reputation",
      resolve: () => {
        const rep = readFlutter("lib/features/archive_reputation/archive_reputation.dart");
        if (!rep.includes("ArchiveReputationView")) {
          return { status: "MISSING", mobileSurface: "—", notes: [] };
        }
        return {
          status: "PARTIAL",
          mobileSurface: "archive_reputation.dart",
          notes: ["Mobile-local reputation score"],
        };
      },
    },
    {
      id: "ownership",
      label: "Ownership",
      resolve: () => {
        const hasExportRoute = flutterHasRoute("/export");
        const protect = readFlutter("lib/widgets/protect_archive_banner.dart");
        if (!hasExportRoute && !protect.includes("ProtectArchiveBanner")) {
          return { status: "MISSING", mobileSurface: "—", notes: [] };
        }
        if (hasExportRoute && protect.includes("ProtectArchiveBanner")) {
          return {
            status: "COMPLETE",
            mobileSurface: "/export + ProtectArchiveBanner",
            notes: [],
          };
        }
        return {
          status: "PARTIAL",
          mobileSurface: hasExportRoute ? "/export" : "protect banner",
          notes: ["Export or protect alone — both needed for full ownership"],
        };
      },
    },
    {
      id: "survival",
      label: "Survival",
      resolve: () => {
        const drawer = readFlutter("lib/widgets/archive_detail_drawer.dart");
        if (!drawer.includes("belief-survival")) {
          return { status: "MISSING", mobileSurface: "—", notes: [] };
        }
        return {
          status: flutterHasRoute("/archive-tool/:tool") ? "PARTIAL" : "MISSING",
          mobileSurface: "/archive-tool/belief-survival",
          notes: ["Drawer tool — simplified survival view"],
        };
      },
    },
    {
      id: "accuracy",
      label: "Accuracy",
      resolve: () => {
        const tools = readFlutter("lib/screens/archive_tool_screen.dart");
        if (!tools.includes("'accuracy'")) {
          return { status: "MISSING", mobileSurface: "—", notes: [] };
        }
        return {
          status: "PARTIAL",
          mobileSurface: "/archive-tool/accuracy",
          notes: ["Local accuracy signals from reputation"],
        };
      },
    },
    {
      id: "contradictions",
      label: "Contradictions",
      resolve: () => {
        if (!flutterHasRoute("/blind-spots")) {
          return { status: "MISSING", mobileSurface: "—", notes: [] };
        }
        return {
          status: "PARTIAL",
          mobileSurface: "/blind-spots",
          notes: ["Simplified blind-spot review — not full web contradiction engine"],
        };
      },
    },
    {
      id: "activity",
      label: "Activity",
      resolve: () => {
        if (!flutterHasScreenToken("DiscoverScreen", "lib/screens/discover_screen.dart")) {
          return { status: "MISSING", mobileSurface: "—", notes: [] };
        }
        return {
          status: "PARTIAL",
          mobileSurface: "/discover (Changes tab)",
          notes: ["Local theory diff — not full archive activity engine"],
        };
      },
    },
    {
      id: "search",
      label: "Search",
      resolve: () => {
        if (!router.includes("'/search'")) {
          return {
            status: "MISSING",
            mobileSurface: "—",
            notes: ["v1.1 — not required for primary journey"],
          };
        }
        return {
          status: "PARTIAL",
          mobileSurface: "/search",
          notes: ["Route exists; not in tab bar — deferred v1.1 per parity plan"],
        };
      },
    },
    {
      id: "export",
      label: "Export",
      resolve: () => {
        if (!flutterHasRoute("/export")) {
          return { status: "MISSING", mobileSurface: "—", notes: [] };
        }
        return {
          status: flutterHasScreenToken("ExportScreen", "lib/screens/export_screen.dart")
            ? "COMPLETE"
            : "PARTIAL",
          mobileSurface: "/export",
          notes: [],
        };
      },
    },
    {
      id: "auth",
      label: "Auth",
      resolve: () => {
        const api = readFlutter("lib/api/api_client.dart");
        const account = readFlutter("lib/screens/account_screen.dart");
        const complete =
          api.includes("sendAuthCode") &&
          api.includes("verifyAuthCode") &&
          account.includes("verifyAuthCode");
        if (!api.includes("sendAuthCode")) {
          return { status: "MISSING", mobileSurface: "—", notes: [] };
        }
        return {
          status: complete ? "COMPLETE" : "PARTIAL",
          mobileSurface: "/account",
          notes: complete ? [] : ["Auth API without full account UI"],
        };
      },
    },
    {
      id: "subscription",
      label: "Subscription",
      resolve: () => {
        const nativeIap = pubspec.includes("purchases_flutter");
        const hasPricing = flutterHasRoute("/pricing");
        const entitlements = readFlutter("lib/billing/billing_service.dart").includes(
          "getEntitlements",
        );
        if (!hasPricing || !entitlements) {
          return { status: "MISSING", mobileSurface: "—", notes: [] };
        }
        if (nativeIap && pricing.toLowerCase().includes("restore")) {
          return {
            status: "COMPLETE",
            mobileSurface: "/pricing + RevenueCat",
            notes: [],
          };
        }
        return {
          status: "PARTIAL",
          mobileSurface: "/pricing → Stripe browser checkout",
          notes: [
            "No RevenueCat — browser checkout + server entitlements",
            nativeIap ? "" : "Add purchases_flutter for store-native primary platform",
          ].filter(Boolean),
        };
      },
    },
  ];

  return specs.map((spec) => {
    const r = spec.resolve();
    return {
      id: spec.id,
      label: spec.label,
      status: r.status,
      mobileSurface: r.mobileSurface,
      notes: r.notes,
    };
  });
}

/** Every archive feature with MISSING | PARTIAL | COMPLETE. */
export function buildMobileParityReport(): MobileParityReport {
  const features = resolveFeatures();
  const missingCount = features.filter((f) => f.status === "MISSING").length;
  const partialCount = features.filter((f) => f.status === "PARTIAL").length;
  const completeCount = features.filter((f) => f.status === "COMPLETE").length;

  const v1Missing = features.filter(
    (f) => V1_REQUIRED.includes(f.id) && f.status === "MISSING",
  );
  const v1RequiredComplete = v1Missing.length === 0;

  const lines = [
    `Features: ${completeCount} complete, ${partialCount} partial, ${missingCount} missing`,
    v1RequiredComplete
      ? "v1 required archive features: none MISSING"
      : `v1 required MISSING: ${v1Missing.map((f) => f.label).join(", ")}`,
  ];

  return {
    generatedAt: new Date().toISOString(),
    features,
    missingCount,
    partialCount,
    completeCount,
    v1RequiredComplete,
    lines,
  };
}

export function formatParityReportMarkdown(report: MobileParityReport): string {
  const rows = report.features
    .map(
      (f) =>
        `| ${f.label} | **${f.status}** | ${f.mobileSurface || "—"} | ${f.notes.join("; ") || "—"} |`,
    )
    .join("\n");

  return [
    "# Mobile parity report",
    "",
    `Generated: ${report.generatedAt}`,
    "",
    "Archive feature parity for Flutter (`apps/voicememory_mobile`) vs web. Status is **evidence from repo structure**, not manual PASS flags.",
    "",
    `| Feature | Status | Mobile surface | Notes |`,
    `| --- | --- | --- | --- |`,
    rows,
    "",
    "## Summary",
    "",
    ...report.lines.map((l) => `- ${l}`),
    "",
    "Search is optional for v1 per `MOBILE_PARITY_PLAN.md`. Subscription **COMPLETE** requires native IAP + restore.",
    "",
  ].join("\n");
}
