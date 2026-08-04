import assert from "node:assert/strict";
import test from "node:test";

import { archiveMeMonetizationPolicy } from "../lib/monetization/generated/archiveMeMonetizationPolicy";
import {
  monetizationDocumentPaths,
  validateMonetizationDocuments,
} from "./monetization-readiness-verifier.mjs";

function validDocuments() {
  const checklistLinks = Object.entries(monetizationDocumentPaths)
    .filter(([name]) => name !== "contract")
    .map(([, relativePath]) => relativePath)
    .join("\n");
  const policyTerms = [
    archiveMeMonetizationPolicy.revenueCat.canonicalProEntitlementId,
    ...archiveMeMonetizationPolicy.revenueCat.acceptedLegacyEntitlementAliases,
    ...archiveMeMonetizationPolicy.revenueCat.currentOfferingPackageKinds,
    ...archiveMeMonetizationPolicy.revenueCat.blockedCurrentPackageKinds,
  ].join("\n");
  const baseChecklist = `# Manual checklist

Manual evidence only.

- [ ] Record external evidence.

${policyTerms}
`;

  return {
    contract: `# Contract

config/monetization/archive_me_entitlement_matrix.json
lib/monetization/generated/archiveMeMonetizationPolicy.ts
apps/voicememory_mobile/lib/features/monetization/domain/generated/monetization_policy.g.dart
${checklistLinks}
${policyTerms}
`,
    release: baseChecklist,
    store: baseChecklist,
    support: baseChecklist,
    revenueCat: baseChecklist,
  };
}

test("accepts documentation aligned with the generated policy", () => {
  assert.deepEqual(
    validateMonetizationDocuments(archiveMeMonetizationPolicy, validDocuments()),
    [],
  );
});

test("rejects canonical entitlement drift", () => {
  const documents = validDocuments();
  documents.contract = documents.contract.replace(
    archiveMeMonetizationPolicy.revenueCat.canonicalProEntitlementId,
    "different_entitlement",
  );

  assert.ok(
    validateMonetizationDocuments(archiveMeMonetizationPolicy, documents).some((error) =>
      error.includes("contract canonical entitlement"),
    ),
  );
});

test("rejects pre-completed manual evidence", () => {
  const documents = validDocuments();
  documents.release = documents.release.replace("- [ ]", "- [x]");

  assert.ok(
    validateMonetizationDocuments(archiveMeMonetizationPolicy, documents).some((error) =>
      error.includes("must not claim completed manual items"),
    ),
  );
});

test("rejects embedded prices and target metrics", () => {
  const documents = validDocuments();
  documents.support += "\nCandidate: £9.99 and 50% conversion.\n";
  const errors = validateMonetizationDocuments(archiveMeMonetizationPolicy, documents);

  assert.ok(errors.some((error) => error.includes("price amounts")));
  assert.ok(errors.some((error) => error.includes("target metrics")));
});
