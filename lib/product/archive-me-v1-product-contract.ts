import capabilityManifest from "../../config/product/archive_me_v1_capabilities.json";
import releaseContract from "../../config/product/archive_me_v1_release_contract.json";

export type V1StartupTier = "required" | "onDemand" | "excluded";

export const archiveMeV1ProductContract = Object.freeze({
  policyVersion: releaseContract.policyVersion,
  primaryRoutes: Object.freeze([...releaseContract.routes.primary]),
  secondaryRoutes: Object.freeze([...releaseContract.routes.secondary]),
  flowRoutes: Object.freeze([...releaseContract.routes.flows]),
  allowedRoutePrefixes: Object.freeze([
    ...releaseContract.routes.allowedPrefixes,
  ]),
  excludedConsumerRoutes: Object.freeze([
    ...releaseContract.routes.explicitlyExcluded,
  ]),
  consumerSurfaces: Object.freeze([
    "record",
    "archive",
    "changes",
    "account",
    "postSaveReceipt",
    "entryDetail",
    "evidenceSource",
  ] as const),
  allowedSecondaryCapabilities: Object.freeze([
    "quickTextCapture",
    "transcriptEditing",
    "encryptedAudioPlayback",
    "archiveSearch",
    "sourceMomentNavigation",
    "interpretationCorrection",
    "recordingRecovery",
    "privacyControls",
    "subscriptionManagement",
    "export",
    "accountDeletion",
  ] as const),
  startupServices: Object.freeze({
    required: Object.freeze([...releaseContract.services.startupRetained]),
    onDemand: Object.freeze([...releaseContract.services.runtimeRetained]),
    excluded: Object.freeze([...releaseContract.services.startupExcluded]),
  }),
  allowedCapabilityGroups: Object.freeze([
    ...capabilityManifest.permittedCapabilityGroups,
  ]),
  prohibitedCapabilityGroups: Object.freeze([
    ...capabilityManifest.prohibitedCapabilityGroups,
  ]),
});

export function isArchiveMeV1ConsumerRouteAllowed(route: string): boolean {
  const path = route.split(/[?#]/u, 1)[0] || "/";
  if (includesValue(archiveMeV1ProductContract.excludedConsumerRoutes, path)) {
    return false;
  }
  return (
    includesValue(archiveMeV1ProductContract.primaryRoutes, path) ||
    includesValue(archiveMeV1ProductContract.secondaryRoutes, path) ||
    includesValue(archiveMeV1ProductContract.flowRoutes, path) ||
    archiveMeV1ProductContract.allowedRoutePrefixes.some((prefix) =>
      path.startsWith(prefix),
    )
  );
}

export function archiveMeV1StartupTier(service: string): V1StartupTier {
  if (
    includesValue(archiveMeV1ProductContract.startupServices.required, service)
  ) {
    return "required";
  }
  if (
    includesValue(archiveMeV1ProductContract.startupServices.onDemand, service)
  ) {
    return "onDemand";
  }
  return "excluded";
}

function includesValue(values: readonly string[], value: string): boolean {
  return values.includes(value);
}
