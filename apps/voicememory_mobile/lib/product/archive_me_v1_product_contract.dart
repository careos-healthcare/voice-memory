import '../router/route_catalog.dart';
import 'auditable_change_positioning.dart';

/// The focused, evidence-first consumer product shipped in V1.
///
/// This is a policy model only. It deliberately contains no Flutter widgets,
/// storage access, or service construction.
abstract final class ArchiveMeV1ProductContract {
  ArchiveMeV1ProductContract._();

  static const category = AuditableChangePositioning.category;

  static const promise = AuditableChangePositioning.primaryPromise;

  static const positioning = AuditableChangePositioning.full;

  static const defensibleProductLine =
      'Auditable personal change: every interpretation shows what ArchiveMe '
      'noticed, why, the exact saved words and dates, the source moment, '
      'uncertainty, and correction controls.';

  static const earlyValuePromise =
      'One moment gives ArchiveMe an observation. Returning gives it '
      'something real to compare.';

  static const primaryRoutes = RouteCatalog.primaryRoutes;

  static const secondaryRoutes = <String>{
    '/settings',
    '/archive-search',
    '/security',
    '/privacy-trust-centre',
    '/privacy',
    '/terms',
    '/about',
    '/support-feedback',
    '/subscription',
    '/pricing',
    '/restore-purchases',
    '/delete-account',
    '/export',
    RouteCatalog.quickTextCapture,
    RouteCatalog.recordingRecovery,
  };

  static const flowRoutes = <String>{'/', RouteCatalog.onboarding};

  static const allowedRoutePrefixes = <String>['/entry/', '/account/'];

  static const excludedConsumerRoutes = <String>{
    '/archive-tools',
    '/life-os',
    '/life-os/graph',
    '/self-discovery',
    '/blind-spots',
    '/archive-identity',
    '/archive-life-chapters',
    '/weekly-report',
    '/capacity-loop',
    '/details',
    '/archive-analyst',
    '/pattern-map',
    '/pattern-profile',
    '/pattern-recognition',
    '/action-items',
    '/archive-review',
    '/weekly-archive-review',
    '/prove-enough/monthly-review',
    '/insight-quality',
    '/archive-timeline',
    '/ask-archive',
    '/archive-cleanup',
    '/moments',
    '/journal',
    '/archive-journey',
    '/archive-share',
    '/archive-deep-dive',
    '/weekly-story',
    '/updates',
    '/archive-packs',
    '/collections',
    '/pinned-evidence',
    '/yesterdays-snapshot',
    '/review-ritual',
    '/archive-calendar',
    '/live-voice',
    '/cold-start/seed',
  };

  static const coreCapabilities = <ArchiveMeV1Capability>{
    ArchiveMeV1Capability.voiceCapture,
    ArchiveMeV1Capability.textCapture,
    ArchiveMeV1Capability.transcriptReview,
    ArchiveMeV1Capability.entryManagement,
    ArchiveMeV1Capability.evidenceBackedObservation,
    ArchiveMeV1Capability.sourceMomentNavigation,
    ArchiveMeV1Capability.encryptedAudioPlayback,
    ArchiveMeV1Capability.archiveSearch,
    ArchiveMeV1Capability.changeComparison,
    ArchiveMeV1Capability.interpretationCorrection,
    ArchiveMeV1Capability.nextRecordingPrompt,
    ArchiveMeV1Capability.optionalReminder,
    ArchiveMeV1Capability.privacyControls,
  };

  static const excludedCapabilities = <ArchiveMeV1Capability>{
    ArchiveMeV1Capability.lifeSimulator,
    ArchiveMeV1Capability.mindMirror,
    ArchiveMeV1Capability.personaForge,
    ArchiveMeV1Capability.autonomousMuse,
    ArchiveMeV1Capability.horizonLab,
    ArchiveMeV1Capability.spatialNexus,
    ArchiveMeV1Capability.healthIntegration,
    ArchiveMeV1Capability.peerToPeerMesh,
    ArchiveMeV1Capability.developerLaboratories,
  };

  static bool isConsumerRouteAllowed(String route) {
    final path = Uri.tryParse(route)?.path ?? route.split('?').first;
    if (excludedConsumerRoutes.contains(path)) return false;
    if (primaryRoutes.contains(path) ||
        secondaryRoutes.contains(path) ||
        flowRoutes.contains(path)) {
      return true;
    }
    return allowedRoutePrefixes.any(path.startsWith);
  }

  static bool shouldInitializeAtStartup(ArchiveMeV1StartupService service) =>
      switch (service) {
        ArchiveMeV1StartupService.captureAndJournal => true,
        ArchiveMeV1StartupService.audioVault => true,
        ArchiveMeV1StartupService.transcriptionQueue => true,
        ArchiveMeV1StartupService.purchaseConfiguration => true,
        ArchiveMeV1StartupService.graphExplorer => false,
        ArchiveMeV1StartupService.semanticClusterRebuild => false,
        ArchiveMeV1StartupService.encryptedGraphSync => false,
        ArchiveMeV1StartupService.localLlamaReconciliation => false,
        ArchiveMeV1StartupService.neuralSculptor => false,
        ArchiveMeV1StartupService.sandboxEnclave => false,
        ArchiveMeV1StartupService.codexPress => false,
        ArchiveMeV1StartupService.apexProfiler => false,
      };
}

enum ArchiveMeV1Capability {
  voiceCapture,
  textCapture,
  transcriptReview,
  entryManagement,
  evidenceBackedObservation,
  sourceMomentNavigation,
  encryptedAudioPlayback,
  archiveSearch,
  changeComparison,
  interpretationCorrection,
  nextRecordingPrompt,
  optionalReminder,
  privacyControls,
  lifeSimulator,
  mindMirror,
  personaForge,
  autonomousMuse,
  horizonLab,
  spatialNexus,
  healthIntegration,
  peerToPeerMesh,
  developerLaboratories,
}

enum ArchiveMeV1StartupService {
  captureAndJournal,
  audioVault,
  transcriptionQueue,
  purchaseConfiguration,
  graphExplorer,
  semanticClusterRebuild,
  encryptedGraphSync,
  localLlamaReconciliation,
  neuralSculptor,
  sandboxEnclave,
  codexPress,
  apexProfiler,
}
