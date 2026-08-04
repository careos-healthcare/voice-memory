import { readFile, writeFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const sourcePath = path.join(
  root,
  "config/monetization/archive_me_entitlement_matrix.json",
);
const outputs = {
  dart: path.join(
    root,
    "apps/voicememory_mobile/lib/features/monetization/domain/generated/monetization_policy.g.dart",
  ),
  typescript: path.join(
    root,
    "lib/monetization/generated/archiveMeMonetizationPolicy.ts",
  ),
};

const source = JSON.parse(await readFile(sourcePath, "utf8"));
validate(source);

const generated = {
  dart: generateDart(source),
  typescript: generateTypeScript(source),
};

if (process.argv.includes("--check")) {
  const drift = [];
  for (const [kind, outputPath] of Object.entries(outputs)) {
    const current = await readFile(outputPath, "utf8").catch(() => "");
    if (current !== generated[kind]) drift.push(path.relative(root, outputPath));
  }
  if (drift.length > 0) {
    throw new Error(
      `Generated monetization contract drifted:\n${drift.map((p) => `- ${p}`).join("\n")}\nRun npm run generate:monetization-contract.`,
    );
  }
  console.log("Monetization contract schema and generated adapters are current.");
} else {
  for (const [kind, outputPath] of Object.entries(outputs)) {
    await writeFile(outputPath, generated[kind], "utf8");
  }
  console.log("Generated Dart and TypeScript monetization adapters.");
}

function validate(policy) {
  assertObject(policy, "policy");
  exactKeys(
    policy,
    [
      "schemaVersion",
      "policyVersion",
      "revenueCat",
      "plans",
      "subscriptionStates",
      "customerFacingCopy",
      "capabilities",
      "usageMeters",
      "legacyMigrationRules",
    ],
    "policy",
  );
  assert(policy.schemaVersion === 1, "schemaVersion must be 1");
  assert(
    /^\d{4}-\d{2}-\d{2}$/.test(policy.policyVersion),
    "policyVersion must be YYYY-MM-DD",
  );
  assertObject(policy.revenueCat, "revenueCat");
  exactKeys(
    policy.revenueCat,
    [
      "canonicalProEntitlementId",
      "acceptedLegacyEntitlementAliases",
      "legacyGrandfatheredProductIds",
      "currentOfferingPackageKinds",
      "blockedCurrentPackageKinds",
    ],
    "revenueCat",
  );
  assertString(policy.revenueCat.canonicalProEntitlementId, "canonical entitlement");
  for (const key of [
    "acceptedLegacyEntitlementAliases",
    "legacyGrandfatheredProductIds",
    "currentOfferingPackageKinds",
    "blockedCurrentPackageKinds",
  ]) {
    assertStringArray(policy.revenueCat[key], `revenueCat.${key}`);
  }

  assertArray(policy.plans, "plans");
  const planKinds = new Set(["free", "pro", "legacyGrandfathered"]);
  const planIds = uniqueIds(policy.plans, "plans");
  for (const plan of policy.plans) {
    exactKeys(plan, ["id", "kind", "availableForNewPurchase"], `plan ${plan.id}`, true);
    assert(planKinds.has(plan.kind), `Unknown plan kind: ${plan.kind}`);
    if ("availableForNewPurchase" in plan) {
      assert(
        typeof plan.availableForNewPurchase === "boolean",
        `Plan ${plan.id} purchase flag must be boolean`,
      );
    }
  }
  assert(planIds.has("free"), "A free plan is required");

  assertStringArray(policy.subscriptionStates, "subscriptionStates");
  for (const required of [
    "free",
    "trial",
    "active",
    "gracePeriod",
    "billingIssue",
    "expired",
    "revoked",
    "legacyGrandfathered",
    "unknown",
  ]) {
    assert(
      policy.subscriptionStates.includes(required),
      `subscriptionStates is missing ${required}`,
    );
  }
  assertObject(policy.customerFacingCopy, "customerFacingCopy");
  for (const [key, value] of Object.entries(policy.customerFacingCopy)) {
    assert(/^[a-z][A-Za-z0-9]*$/.test(key), `Invalid copy key: ${key}`);
    assertString(value, `customerFacingCopy.${key}`);
  }

  assertArray(policy.usageMeters, "usageMeters");
  const meterIds = uniqueIds(policy.usageMeters, "usageMeters");
  for (const meter of policy.usageMeters) {
    exactKeys(
      meter,
      ["id", "unit", "period", "productionConfigurationRequired"],
      `usage meter ${meter.id}`,
    );
    assert(["seconds", "requests"].includes(meter.unit), `Invalid unit for ${meter.id}`);
    assert(meter.period === "billingPeriod", `Invalid period for ${meter.id}`);
    assert(
      typeof meter.productionConfigurationRequired === "boolean",
      `Invalid configuration flag for ${meter.id}`,
    );
  }

  assertArray(policy.capabilities, "capabilities");
  uniqueIds(policy.capabilities, "capabilities");
  const accessClasses = new Set([
    "userOwned",
    "freeProof",
    "proMetered",
    "pro",
    "metered",
  ]);
  for (const capability of policy.capabilities) {
    exactKeys(
      capability,
      [
        "id",
        "accessClass",
        "expiryBehaviour",
        "offlineBehaviour",
        "usageMeterId",
        "copyKey",
      ],
      `capability ${capability.id}`,
      true,
    );
    assert(
      accessClasses.has(capability.accessClass),
      `Invalid access class for ${capability.id}`,
    );
    for (const key of ["expiryBehaviour", "offlineBehaviour", "copyKey"]) {
      assertString(capability[key], `${capability.id}.${key}`);
    }
    assert(
      capability.copyKey in policy.customerFacingCopy,
      `${capability.id} references unknown copy key ${capability.copyKey}`,
    );
    if (capability.usageMeterId !== undefined) {
      assert(
        meterIds.has(capability.usageMeterId),
        `${capability.id} references unknown meter ${capability.usageMeterId}`,
      );
    }
    if (["proMetered", "metered"].includes(capability.accessClass)) {
      assert(
        capability.usageMeterId !== undefined,
        `${capability.id} requires a usage meter`,
      );
    }
  }

  const rules = policy.legacyMigrationRules;
  assertObject(rules, "legacyMigrationRules");
  const requiredTrue = [
    "preserveOriginalContentAccess",
    "preserveGeneratedOutputReadAccess",
    "doNotConsumeFreeProofFromLegacyCounters",
    "honourActiveLegacyEntitlementAliases",
    "honourVerifiedLifetimePurchasersAsLegacyGrandfathered",
  ];
  exactKeys(
    rules,
    [...requiredTrue, "allowNewLifetimePurchases"],
    "legacyMigrationRules",
  );
  for (const key of requiredTrue) assert(rules[key] === true, `${key} must remain true`);
  assert(
    rules.allowNewLifetimePurchases === false,
    "allowNewLifetimePurchases must remain false",
  );
}

function generateDart(policy) {
  const planKinds = unique(policy.plans.map((p) => p.kind));
  const capabilities = policy.capabilities.map((c) => c.id);
  const accessClasses = unique(policy.capabilities.map((c) => c.accessClass));
  const usageMeters = policy.usageMeters.map((m) => m.id);
  const subscriptionStates = policy.subscriptionStates;
  const copyConstants = Object.entries(policy.customerFacingCopy)
    .map(([key, value]) => `  static const String ${key} = ${dartString(value)};`)
    .join("\n");
  const descriptorRows = policy.capabilities
    .map(
      (c) => `    CapabilityId.${c.id}: MonetizationCapability(
      id: CapabilityId.${c.id},
      accessClass: AccessClass.${c.accessClass},
      expiryBehaviour: ${dartString(c.expiryBehaviour)},
      offlineBehaviour: ${dartString(c.offlineBehaviour)},
      ${c.usageMeterId ? `usageMeterId: UsageMeterId.${c.usageMeterId},\n      ` : ""}copyKey: ${dartString(c.copyKey)},
    ),`,
    )
    .join("\n");

  return `// GENERATED CODE - DO NOT MODIFY BY HAND.
// Source: config/monetization/archive_me_entitlement_matrix.json

enum PlanKind { ${planKinds.join(", ")} }

enum CapabilityId {
${capabilities.map((id) => `  ${id},`).join("\n")}
}

enum AccessClass { ${accessClasses.join(", ")} }

enum UsageMeterId {
${usageMeters.map((id) => `  ${id},`).join("\n")}
}

enum PolicySubscriptionState { ${subscriptionStates.join(", ")} }

class MonetizationCapability {
  const MonetizationCapability({
    required this.id,
    required this.accessClass,
    required this.expiryBehaviour,
    required this.offlineBehaviour,
    required this.copyKey,
    this.usageMeterId,
  });

  final CapabilityId id;
  final AccessClass accessClass;
  final String expiryBehaviour;
  final String offlineBehaviour;
  final UsageMeterId? usageMeterId;
  final String copyKey;
}

abstract final class MonetizationPolicy {
  static const int schemaVersion = ${policy.schemaVersion};
  static const String policyVersion = ${dartString(policy.policyVersion)};
  static const String canonicalProEntitlementId =
      ${dartString(policy.revenueCat.canonicalProEntitlementId)};
  static const Set<String> acceptedLegacyEntitlementAliases = {
${policy.revenueCat.acceptedLegacyEntitlementAliases.map((id) => `    ${dartString(id)},`).join("\n")}
  };
  static const Set<String> legacyGrandfatheredProductIds = {
${policy.revenueCat.legacyGrandfatheredProductIds.map((id) => `    ${dartString(id)},`).join("\n")}
  };
  static const Set<String> currentOfferingPackageKinds = {
${policy.revenueCat.currentOfferingPackageKinds.map((id) => `    ${dartString(id)},`).join("\n")}
  };
  static const Set<String> blockedCurrentPackageKinds = {
${policy.revenueCat.blockedCurrentPackageKinds.map((id) => `    ${dartString(id)},`).join("\n")}
  };

${copyConstants}

  static const Map<CapabilityId, MonetizationCapability> capabilities = {
${descriptorRows}
  };

  static MonetizationCapability capability(CapabilityId id) => capabilities[id]!;
}
`;
}

function generateTypeScript(policy) {
  const planKinds = unique(policy.plans.map((p) => p.kind));
  const capabilities = policy.capabilities.map((c) => c.id);
  const accessClasses = unique(policy.capabilities.map((c) => c.accessClass));
  const usageMeters = policy.usageMeters.map((m) => m.id);
  const subscriptionStates = policy.subscriptionStates;
  return `// GENERATED CODE - DO NOT MODIFY BY HAND.
// Source: config/monetization/archive_me_entitlement_matrix.json

export type PlanKind = ${union(planKinds)};
export type CapabilityId = ${union(capabilities)};
export type AccessClass = ${union(accessClasses)};
export type UsageMeterId = ${union(usageMeters)};
export type PolicySubscriptionState = ${union(subscriptionStates)};

export interface MonetizationCapability {
  readonly id: CapabilityId;
  readonly accessClass: AccessClass;
  readonly expiryBehaviour: string;
  readonly offlineBehaviour: string;
  readonly usageMeterId?: UsageMeterId;
  readonly copyKey: string;
}

export interface ArchiveMeMonetizationPolicy {
  readonly schemaVersion: 1;
  readonly policyVersion: string;
  readonly revenueCat: {
    readonly canonicalProEntitlementId: string;
    readonly acceptedLegacyEntitlementAliases: readonly string[];
    readonly legacyGrandfatheredProductIds: readonly string[];
    readonly currentOfferingPackageKinds: readonly string[];
    readonly blockedCurrentPackageKinds: readonly string[];
  };
  readonly plans: readonly {
    readonly id: string;
    readonly kind: PlanKind;
    readonly availableForNewPurchase?: boolean;
  }[];
  readonly subscriptionStates: readonly PolicySubscriptionState[];
  readonly customerFacingCopy: Readonly<Record<string, string>>;
  readonly capabilities: readonly MonetizationCapability[];
  readonly usageMeters: readonly {
    readonly id: UsageMeterId;
    readonly unit: "seconds" | "requests";
    readonly period: "billingPeriod";
    readonly productionConfigurationRequired: boolean;
  }[];
  readonly legacyMigrationRules: {
    readonly preserveOriginalContentAccess: true;
    readonly preserveGeneratedOutputReadAccess: true;
    readonly doNotConsumeFreeProofFromLegacyCounters: true;
    readonly honourActiveLegacyEntitlementAliases: true;
    readonly honourVerifiedLifetimePurchasersAsLegacyGrandfathered: true;
    readonly allowNewLifetimePurchases: false;
  };
}

export const archiveMeMonetizationPolicy =
  ${JSON.stringify(policy, null, 2).replace(/\n/g, "\n  ")} as const satisfies ArchiveMeMonetizationPolicy;

export const capabilityById: Readonly<Record<CapabilityId, MonetizationCapability>> =
  Object.freeze(Object.fromEntries(
    archiveMeMonetizationPolicy.capabilities.map((capability) => [capability.id, capability]),
  ) as Record<CapabilityId, MonetizationCapability>);
`;
}

function uniqueIds(items, label) {
  const ids = new Set();
  for (const item of items) {
    assertObject(item, `${label} item`);
    assertString(item.id, `${label} id`);
    assert(!ids.has(item.id), `Duplicate ${label} id: ${item.id}`);
    assert(/^[a-z][A-Za-z0-9_]*$/.test(item.id), `Invalid identifier: ${item.id}`);
    ids.add(item.id);
  }
  return ids;
}

function exactKeys(value, keys, label, optional = false) {
  const allowed = new Set(keys);
  for (const key of Object.keys(value)) {
    assert(allowed.has(key), `${label} has unknown property: ${key}`);
  }
  if (!optional) {
    for (const key of keys) assert(key in value, `${label} is missing ${key}`);
  }
}

function assertStringArray(value, label) {
  assertArray(value, label);
  const seen = new Set();
  for (const item of value) {
    assertString(item, label);
    assert(!seen.has(item), `${label} contains duplicate ${item}`);
    seen.add(item);
  }
}

function assertArray(value, label) {
  assert(Array.isArray(value) && value.length > 0, `${label} must be a non-empty array`);
}

function assertObject(value, label) {
  assert(value !== null && typeof value === "object" && !Array.isArray(value), `${label} must be an object`);
}

function assertString(value, label) {
  assert(typeof value === "string" && value.length > 0, `${label} must be a string`);
}

function assert(condition, message) {
  if (!condition) throw new Error(`Invalid monetization policy: ${message}`);
}

function unique(values) {
  return [...new Set(values)];
}

function dartString(value) {
  return `'${value.replaceAll("\\", "\\\\").replaceAll("'", "\\'")}'`;
}

function union(values) {
  return values.map((value) => JSON.stringify(value)).join(" | ");
}

