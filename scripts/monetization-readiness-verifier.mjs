import { readFile } from "node:fs/promises";
import path from "node:path";

export const monetizationDocumentPaths = Object.freeze({
  contract: "docs/current/MONETIZATION_CONTRACT.md",
  release: "docs/monetization/RELEASE_MANUAL_CHECKLIST.md",
  store: "docs/monetization/STORE_MANUAL_CHECKLIST.md",
  support: "docs/monetization/SUPPORT_MANUAL_CHECKLIST.md",
  revenueCat: "docs/monetization/REVENUECAT_MANUAL_CHECKLIST.md",
});

export async function verifyMonetizationReadiness({ root, policy }) {
  const documents = Object.fromEntries(
    await Promise.all(
      Object.entries(monetizationDocumentPaths).map(async ([name, relativePath]) => [
        name,
        await readFile(path.join(root, relativePath), "utf8"),
      ]),
    ),
  );

  return validateMonetizationDocuments(policy, documents);
}

export function validateMonetizationDocuments(policy, documents) {
  const errors = [];
  const entitlement = policy?.revenueCat?.canonicalProEntitlementId;
  const aliases = policy?.revenueCat?.acceptedLegacyEntitlementAliases ?? [];
  const currentPackages = policy?.revenueCat?.currentOfferingPackageKinds ?? [];
  const blockedPackages = policy?.revenueCat?.blockedCurrentPackageKinds ?? [];

  requireString(entitlement, "generated canonical entitlement", errors);
  requireStringArray(aliases, "generated legacy entitlement aliases", errors);
  requireStringArray(currentPackages, "generated current package kinds", errors);
  requireStringArray(blockedPackages, "generated blocked package kinds", errors);

  for (const name of Object.keys(monetizationDocumentPaths)) {
    if (typeof documents[name] !== "string" || documents[name].trim() === "") {
      errors.push(`${name} documentation is missing or empty`);
    }
  }
  if (errors.length > 0) return errors;

  const contract = documents.contract;
  requireIncludes(
    contract,
    "config/monetization/archive_me_entitlement_matrix.json",
    "contract canonical source",
    errors,
  );
  requireIncludes(
    contract,
    "lib/monetization/generated/archiveMeMonetizationPolicy.ts",
    "contract generated TypeScript adapter",
    errors,
  );
  requireIncludes(
    contract,
    "apps/voicememory_mobile/lib/features/monetization/domain/generated/monetization_policy.g.dart",
    "contract generated Dart adapter",
    errors,
  );
  requireIncludes(contract, entitlement, "contract canonical entitlement", errors);
  for (const alias of aliases) {
    requireIncludes(contract, alias, `contract legacy alias ${alias}`, errors);
  }
  for (const packageKind of currentPackages) {
    requireIncludes(contract, packageKind, `contract package kind ${packageKind}`, errors);
  }
  for (const packageKind of blockedPackages) {
    requireIncludes(
      contract,
      packageKind,
      `contract blocked package kind ${packageKind}`,
      errors,
    );
  }

  for (const [name, relativePath] of Object.entries(monetizationDocumentPaths)) {
    if (name === "contract") continue;
    requireIncludes(contract, relativePath, `contract link to ${name} checklist`, errors);
    if (!/\bmanual\b/i.test(documents[name])) {
      errors.push(`${relativePath} must identify itself as manual`);
    }
    if (!documents[name].includes("- [ ]")) {
      errors.push(`${relativePath} must contain unchecked manual items`);
    }
    if (/- \[[xX]\]/.test(documents[name])) {
      errors.push(`${relativePath} must not claim completed manual items`);
    }
  }

  for (const name of ["store", "revenueCat"]) {
    const document = documents[name];
    requireIncludes(document, entitlement, `${name} canonical entitlement`, errors);
    for (const packageKind of currentPackages) {
      requireIncludes(document, packageKind, `${name} package kind ${packageKind}`, errors);
    }
    for (const packageKind of blockedPackages) {
      requireIncludes(
        document,
        packageKind,
        `${name} blocked package kind ${packageKind}`,
        errors,
      );
    }
  }

  const documentationBundle = Object.values(documents).join("\n");
  if (/[£€¥]\s?\d|\$\s?\d/.test(documentationBundle)) {
    errors.push("monetization contract/checklists must not embed price amounts");
  }
  if (/\b\d+(?:\.\d+)?\s*%/.test(documentationBundle)) {
    errors.push("monetization contract/checklists must not embed target metrics");
  }

  return errors;
}

function requireIncludes(document, expected, label, errors) {
  if (!document.includes(expected)) errors.push(`${label} is missing ${JSON.stringify(expected)}`);
}

function requireString(value, label, errors) {
  if (typeof value !== "string" || value.length === 0) errors.push(`${label} is invalid`);
}

function requireStringArray(value, label, errors) {
  if (!Array.isArray(value) || value.length === 0 || value.some((item) => typeof item !== "string")) {
    errors.push(`${label} is invalid`);
  }
}
