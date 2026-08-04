import { access, readFile, readdir } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const policy = JSON.parse(
  await read("config/monetization/archive_me_entitlement_matrix.json"),
);
const canonical = policy.revenueCat.canonicalProEntitlementId;

assert(
  canonical === "archive_loop_pro",
  "canonical entitlement changed from production",
);
assert(
  (await read(".github/workflows/build_and_deploy.yml")).includes(canonical),
  "production workflow does not agree with the canonical entitlement",
);
for (const target of [
  "apps/voicememory_mobile/lib/billing/archive_loop_entitlement_ids.dart",
  "apps/voicememory_mobile/lib/subscriptions/domain/subscription_models.dart",
]) {
  assert(
    (await read(target)).includes(
      "MonetizationPolicy.canonicalProEntitlementId",
    ),
    `${target} must delegate the canonical entitlement to generated policy`,
  );
}

const generatedTargets = [
  "apps/voicememory_mobile/lib/features/monetization/domain/generated/monetization_policy.g.dart",
  "lib/monetization/generated/archiveMeMonetizationPolicy.ts",
];
for (const target of generatedTargets) {
  const source = await read(target);
  assert(
    source.startsWith("// GENERATED CODE"),
    `${target} lacks generated marker`,
  );
  assert(source.includes(canonical), `${target} lost canonical entitlement`);
}

const retiredPolicySystems = [
  "apps/voicememory_mobile/lib/billing/archive_pro_feature_map.dart",
  "apps/voicememory_mobile/lib/features/pro_memory/pro_memory_boundary_engine.dart",
  "apps/voicememory_mobile/lib/features/comparison_engine/domain/services/pro_trail_gate.dart",
];
for (const target of retiredPolicySystems) {
  assert(!(await exists(target)), `${target} must remain physically removed`);
}

const mobileLib = path.join(root, "apps/voicememory_mobile/lib");
for (const file of await filesUnder(mobileLib, ".dart")) {
  const source = await readFile(file, "utf8");
  for (const forbidden of [
    "freeKeyMomentsLimit",
    "freeRecentSavedMomentLimit",
    "freePatternDetailMomentLimit",
    "freeHistoricalMomentLimit",
    "Free keeps your first 7 key moments",
    "Only the latest three moments are available",
    "Upgrade to see older recordings",
    "Upgrade to unlock your archive",
    "Upgrade to play your recording",
    "unlimited AI",
  ]) {
    assert(
      !source.includes(forbidden),
      `${path.relative(root, file)} depends on retired ${forbidden}`,
    );
  }
}

const webStorage = await read("lib/storage.ts");
assert(
  /export function getEntries\(\): JournalEntry\[\] \{\s*return loadAllEntries\(\);\s*\}/m.test(
    webStorage,
  ),
  "web archive must return every user-owned entry without a plan limit",
);
const webResurfacing = await read("lib/entitlement/resurfacing-scope.ts");
assert(
  !webResurfacing.includes(".slice(") &&
    !webResurfacing.includes("hasEntitlement("),
  "web resurfacing must not truncate user-owned history by plan",
);
// The guard's concern is that web export must not gate a user's own content
// behind Pro. A page that no longer ships cannot carry such a gate, so absence
// satisfies the contract rather than aborting the whole run.
const WEB_EXPORT_PAGE = "app/export/page.tsx";
if (await exists(WEB_EXPORT_PAGE)) {
  const webExport = await read(WEB_EXPORT_PAGE);
  for (const forbidden of [
    "requiresProForExportReports",
    "locked on Pro",
    "Upgrade to print",
    "Pro required",
  ]) {
    assert(
      !webExport.includes(forbidden),
      `web export retains original-content gate ${forbidden}`,
    );
  }
}
const retiredWebCheckout = await read("app/api/billing/checkout/route.ts");
assert(
  retiredWebCheckout.includes("MOBILE_STORE_PURCHASE_REQUIRED") &&
    !retiredWebCheckout.includes("checkout.sessions.create"),
  "web checkout must not sell a parallel subscription outside RevenueCat",
);
assert(
  !(await exists("lib/billing/start-checkout.ts")),
  "web Stripe checkout client must remain removed",
);
const retiredWebPaywall = await read("lib/billing/value-moment-paywall.ts");
for (const forbidden of [
  "reflectionCount >=",
  "getCurrentTierId",
  "isProTier",
]) {
  assert(
    !retiredWebPaywall.includes(forbidden),
    `retired web paywall retains independent decision ${forbidden}`,
  );
}
assert(
  /export function shouldShowValueMomentPaywall[\s\S]*?return false;/m.test(
    retiredWebPaywall,
  ),
  "retired web paywall must remain disabled",
);
for (const directory of ["app", "components", "lib/billing"]) {
  for (const suffix of [".ts", ".tsx"]) {
    for (const file of await filesUnder(path.join(root, directory), suffix)) {
      const source = await readFile(file, "utf8");
      assert(
        !/[£€¥]\s?\d|\$\s+\d|\$\d+\.\d{2}/.test(source),
        `${path.relative(root, file)} embeds a production price`,
      );
      assert(
        !/\bunlimited AI\b/i.test(source),
        `${path.relative(root, file)} claims unlimited AI`,
      );
    }
  }
}

const serverPolicy = await read("lib/server/monetization-policy.ts");
assert(
  serverPolicy.includes(
    "@/lib/monetization/generated/archiveMeMonetizationPolicy",
  ),
  "TypeScript server adapter must consume generated policy",
);
assert(
  !serverPolicy.includes(
    "@/config/monetization/archive_me_entitlement_matrix.json",
  ),
  "TypeScript server adapter must not parse the source independently",
);

assert(
  (
    await read(
      "apps/voicememory_mobile/lib/services/composition/monetization_services.dart",
    )
  ).includes("MonetizationLocalMigration(core.prefs)"),
  "local monetization migration must run through the subscription cache adapter",
);

assert(
  !(await exists(
    "apps/voicememory_mobile/lib/billing/paywall_trigger_engine.dart",
  )),
  "parallel paywall trigger engine must be absent from the shipping workspace",
);

const legacyLoopAdapter = await read(
  "apps/voicememory_mobile/lib/features/paywall/archive_loop_entitlements.dart",
);
assert(
  legacyLoopAdapter.includes("AccessPolicyEngine.decide("),
  "legacy loop UI must delegate decisions to AccessPolicyEngine",
);
for (const retiredDecision of [
  "mapCount <",
  "evidenceCount <",
  "editCount <",
  "returnCheckCount <",
]) {
  assert(
    !legacyLoopAdapter.includes(retiredDecision),
    `legacy loop UI retains independent quota decision ${retiredDecision}`,
  );
}

assert(
  !(await exists(
    "apps/voicememory_mobile/lib/widgets/prove_enough/prove_enough_pattern_report_export_button.dart",
  )),
  "retired pattern-report export must be absent from the shipping workspace",
);

const paywallScreen = await read(
  "apps/voicememory_mobile/lib/screens/paywall_screen.dart",
);
assert(
  !/\.isPro\b/.test(paywallScreen),
  "paywall screen bypasses the canonical entitlement snapshot",
);
const paywallSource = await read(
  "apps/voicememory_mobile/lib/billing/paywall_source.dart",
);
assert(
  paywallSource.includes("MonetizationPolicy.ongoingComparisons"),
  "paywall benefits do not consume canonical customer-facing copy",
);

for (const target of [
  "apps/voicememory_mobile/lib/screens/paywall_screen.dart",
]) {
  const source = await read(target);
  assert(
    !/[£€¥]\s?\d|\$\s?\d/.test(source),
    `${target} embeds a production price`,
  );
  assert(!/\bunlimited AI\b/i.test(source), `${target} claims unlimited AI`);
  assert(!/\blifetime\b/i.test(source), `${target} exposes lifetime sale copy`);
}

console.log("Monetization static contract guards passed.");

async function read(relativePath) {
  return readFile(path.join(root, relativePath), "utf8");
}

async function exists(relativePath) {
  return access(path.join(root, relativePath)).then(
    () => true,
    () => false,
  );
}

async function filesUnder(directory, suffix) {
  const results = [];
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const entryPath = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      results.push(...(await filesUnder(entryPath, suffix)));
    } else if (entry.name.endsWith(suffix)) {
      results.push(entryPath);
    }
  }
  return results;
}

function assert(condition, message) {
  if (!condition)
    throw new Error(`Monetization contract guard failed: ${message}`);
}
