// Syncs field types from RecordSurfaceViewState into RecordBuildContext (part file),
// applies [knownFieldTypes] to both files, and regenerates the type-export barrel.
//
// Run from apps/mobile:
//   dart run tool/sync_record_build_context_types.dart

import 'dart:io';

/// Explicit types for resolver/engine payloads still stored as dynamic.
const knownFieldTypes = {
  'policyMic': 'RecordingPhase',
  'readyCapturePolicy': 'RecordCtaPolicyResolution',
  'recordHomeSurface': 'RecordHomeSurfacePolicy',
  'stack': 'RecordStackDecision',
  'dailyArchiveExercise': 'DailyArchiveExerciseResult?',
  'testerMission': 'TesterMissionResult?',
  'testerMissionCompact': 'bool',
  'dailyArchiveMemoryCandidate': 'DailyArchiveMemoryResult?',
  'proBridgeVisibilityRecordResult': 'ProBridgeVisibilityResult?',
  'proBridgeVisibilityPostSaveResult': 'ProBridgeVisibilityResult?',
  'recordPostSaveSurfacePriority': 'SurfacePriorityResult?',
  'firstProofLoopActive': 'bool',
  'recordReadyShowsWatchTargetOnly': 'bool',
  'recordReadySuppressStreakPressure': 'bool',
  'daysSinceLastEntry': 'int?',
  'patternConfidenceEducationCount': 'int',
  'timelineProofParentVisible': 'bool',
  'firstProofPayoffParentVisible': 'bool',
  'timelineProofPostSaveParentVisible': 'bool',
  'blocksProByProofFloorOnRecord': 'bool',
  'blocksProByProofFloorOnPostSave': 'bool',
  'blocksProCardsByProofProtectionOnRecord': 'bool',

  'auditPresentation': 'RecordAuditPresentation?',
  'secondSessionPayoff': 'SecondSessionPayoff?',
  'thirdEntryBeliefPayoff': 'ThirdEntryBeliefPayoff?',
  'confirmedRepeatTriggerPayoff': 'ConfirmedRepeatTriggerPayoff?',
  'confirmedRepeatHelpfulActionPayoff': 'ConfirmedRepeatHelpfulActionPayoff?',
  'confirmedRepeatChangeNotice': 'ConfirmedRepeatChangeNotice?',
  'confirmedRepeatChangeNoticeOnRecord': 'ConfirmedRepeatChangeNotice?',
  'repeatReturnCheckOffer': 'RepeatReturnCheckOffer?',
  'returnCheckPayoffCandidate': 'ReturnCheckPayoff?',
  'beliefUpdatePayoff': 'BeliefUpdatePayoff?',
  'returnLoopPayoff': 'DayTwoReturnLoopPayoff?',
  'whatChangedV2Prompt': 'WhatChangedV2Prompt?',
  'whatChangedV2Display': 'WhatChangedV2Prompt?',
  'helpedTrackingPrompt': 'HelpedTrackingPrompt?',
  'earlyEvidenceTimeline': 'EarlyEvidenceTimeline?',
  'earlyFirstSignalOnRecord': 'EarlyFirstSignalModel?',
  'repeatReturnChangeProof': 'RepeatReturnCheckChangeProof?',
  'patternChangedCandidate': 'PatternChangedResult?',
  'confirmedRepeatThoughtMap': 'ThoughtMapResult?',
  'positivePattern': 'PositivePatternResult?',
  'helpfulActionAppearedCandidate': 'HelpfulActionAppeared?',
  'positiveReinforcement': 'PositiveReinforcementResult?',
  'archiveSummaryCandidate': 'ArchiveSummaryResult?',
  'archiveBeliefSurfaceCandidate': 'ArchiveBeliefSurface',
  'patternNamePrompt': 'PatternNamePrompt?',
  'dailyReturnReasonCandidate': 'DailyReturnReasonResult?',
  'archiveSummary': 'ArchiveSummaryResult?',
  'dailyReturnReason': 'DailyReturnReasonResult?',
  'archiveWatchingCandidate': 'ArchiveWatchingResult?',
  'archiveWatching': 'ArchiveWatchingResult?',
  'weeklyArchiveReview': 'WeeklyArchiveReviewResult?',
  'privateArchiveReportCandidate': 'PrivateArchiveReport?',
  'privateArchiveReportForProGate': 'PrivateArchiveReport?',
  'firstWeekLoopCandidate': 'FirstWeekLoop?',
  'proofSurfaceLayout': 'ArchiveProofSurfaceLayout',
  'recordProofStack': 'RecordProofStackDecision',
  'lowEvidenceGuidance': 'LowEvidenceGuidance?',
  'quietSignalCandidate': 'QuietSignal?',
  'repeatPostSaveThoughtMapPreview': 'ArchiveThoughtMapPreview?',
  'postProofArchiveProof': 'bool',
  'archiveSummaryVisibleForProGate': 'bool',
  'weeklyArchiveReviewVisibleForProGate': 'bool',
  'privateArchiveReportPreviewForProGate': 'bool',
  'patternChangedForProGate': 'bool',
  'firstProofPayoffSeenOnRecord': 'bool',
  'currentRelevanceCandidate': 'CurrentRelevanceState?',
  'correctionMemoryCandidate': 'CorrectionMemoryResult?',
  'evidenceWeightingCandidate': 'EvidenceWeightingResult?',
  'proofSpecificityCandidate': 'ProofSpecificityResult',
  'presentDayRelevanceCandidate': 'PresentDayRelevanceResult?',
  'timelinePositioningCandidate': 'TimelinePositioningResult',
  'otherEducationCardsOnRecord': 'int',
  'patternConfidenceExplanationCandidate': 'PatternConfidenceExplanationResult?',
  'notRelevantRecoveryCandidate': 'NotRelevantRecoveryResult',
  'proofQualityResponseTimelineCandidate': 'ProofQualityResponseResult',
  'proofQualityResponseSpineCandidate': 'ProofQualityResponseResult',
  'betaProofLiftTimelineCandidate': 'BetaProofLiftResult',
  'proofSpecificityBoostCandidate': 'ProofSpecificityBoostResult',
  'returnAfterProofRecordCandidate': 'ReturnAfterProofResult',
  'returnAfterProofLiftV2Candidate': 'ReturnAfterProofLiftV2Result',
  'patternReviewInboxActivePostSave': 'bool',
  'firstProofPayoffCandidate': 'FirstProofPayoff?',
  'threeDayChallengeCandidate': 'ThreeDayChallengeState?',
  'firstProofPatternConfidence': 'PatternConfidence?',
  'firstProofTruthProofKey': 'String',
  'firstProofTruthAnswer': 'FirstProofTruthAnswer?',
  'firstProofActionLoopContent': 'FirstProofActionLoopContent?',
  'timelineProofMomentPostSaveCandidate': 'TimelineProofMomentResult?',
  'proofSpecificityPostSaveCandidate': 'ProofSpecificityResult',
  'proofSpecificityBoostPostSaveCandidate': 'ProofSpecificityBoostResult',
  'proofQualityResponseFirstProofCandidate': 'ProofQualityResponseResult',
  'proofQualityResponseTimelinePostSaveCandidate': 'ProofQualityResponseResult',
  'betaProofLiftFirstProofCandidate': 'BetaProofLiftResult',
  'betaProofLiftTimelinePostSaveCandidate': 'BetaProofLiftResult',
  'returnAfterProofPostSaveCandidate': 'ReturnAfterProofResult',
  'returnAfterProofLiftV2PostSaveCandidate': 'ReturnAfterProofLiftV2Result',
  'firstMomentCaptureCandidate': 'FirstMomentCaptureResult',
  'firstSaveLiftCandidate': 'FirstSaveLiftResult',
  'firstSessionCaptureRepairCandidate': 'FirstSessionCaptureRepairResult',
  'openingRepairOverride': 'FirstSessionCaptureRepairResult?',
  'firstSessionLiftCandidate': 'FirstSessionLiftResult',
  'secondMomentReturnCandidate': 'SecondMomentReturnResult',
  'threeMomentCompletionCandidate': 'ThreeMomentCompletionResult',
  'firstRunPositioningCandidate': 'FirstRunPositioningResult',
  'betaTodaySummaryCandidate': 'BetaTodaySummaryResult',
  'archiveTimelineSpineCandidate': 'ArchiveTimelineSpineResult?',
  'whatToNoticeNextCandidate': 'WhatToNoticeNextResult',
  'timelineProofMomentCandidate': 'TimelineProofMomentResult?',
  'betaTesterReportCandidate': 'BetaTesterReportResult',
  'betaTestScriptCardCandidate': 'BetaTestScriptCompactCard?',
  'nextBestActionCandidate': 'NextBestActionResult?',
  'returnTomorrowCueReady': 'ReturnTomorrowCue?',
  'returnDayFlowCandidate': 'ReturnDayFlow?',
  'firstWeekProgressReady': 'FirstWeekProgress?',
  'returnTomorrowCuePostSave': 'ReturnTomorrowCue?',
  'comeBackTomorrowV2PostSaveWatch': 'ComeBackTomorrowPostSaveWatch?',
  'postSaveDegradedForReturnCue': 'bool',
  'postSaveReturnHandoffCandidate': 'PostSaveReturnHandoff?',
  'firstWeekProgressPostSave': 'FirstWeekProgress?',
  'returningUserToday': 'ReturningUserToday?',
  'nextMomentPrompt': 'NextMomentPrompt?',
  'todaysOneQuestion': 'TodaysQuestionResult?',
  'recordReadySurfacePriority': 'SurfacePriorityResult?',
  'recordLoosenSignalsPreAudit': 'ProBridgeTimingLoosenSignals',
  'recordEvidenceAnchorPreAudit': 'EvidenceAnchorExtractionResult',
  'recordFeedbackStateForLift': 'ProofQualityFeedbackState',
  'timelineFeedbackType': 'BetaProofFeedbackType?',
  'betaRepairLabInput': 'BetaRepairLabVisibilityInput',
  'betaRepairLabProPlacementResult': 'BetaRepairLabProPlacementResult',
  'betaRepairLabPricingValueFramingResult': 'PricingValueFramingResult',
  'betaRepairLabPaywallValueResult': 'PaywallValueRepairResult',
  'betaRepairLabPricingValidationResult': 'PricingValidationResult',
  'betaRepairLabProofResult': 'BetaRepairLabProofResult',
  'betaRepairLabEvidenceTrailClarityResult': 'EvidenceTrailClarityResult',
  'proofQualityRepairInput': 'ProofQualityRepairVisibilityInput',
  'proofQualityRepairResult': 'ProofQualityRepairResult',
  'proofFloorRescueInput': 'ProofFloorRescueInput',
  'proofFloorRescueResult': 'ProofFloorRescueResult',
  'recordLoosenSignals': 'ProBridgeTimingLoosenSignals?',
  'recordReadyProTiming': 'ProMomentTimingContext?',
  'betaProofFeedbackRowVisibleOnTimeline': 'bool',
  'betaProofFeedbackCounts': 'dynamic',
  'proUnderstandingLiftRecordReadyInput': 'ProUnderstandingLiftVisibilityInput',
  'proUnderstandingLiftRecordReadyResult': 'ProUnderstandingLiftResult?',
  'proVisibilityLiftRecordReadyResult': 'ProVisibilityLiftResult?',
  'proUnderstandingLiftPostSaveInput': 'ProUnderstandingLiftVisibilityInput',
  'proUnderstandingLiftPostSaveResult': 'ProUnderstandingLiftResult?',
  'base': 'ProUnderstandingLiftResult?',
  'proVisibilityLiftPostSaveResult': 'ProVisibilityLiftResult?',
  'postSaveLoosenSignalsPreAudit': 'ProBridgeTimingLoosenSignals',
  'postSaveEvidenceAnchorPreAudit': 'EvidenceAnchorExtractionResult',
  'postSaveFeedbackStateForLift': 'ProofQualityFeedbackState',
  'postSaveProofFloorRescueInput': 'ProofFloorRescueInput',
  'postSaveLoosenSignals': 'ProBridgeTimingLoosenSignals?',
  'postSaveProTiming': 'ProMomentTimingContext?',
  'betaActivationPathPreAuditContext': 'BetaActivationPathContext',
  'betaActivationPathPreAuditResult': 'BetaActivationPathResult',
  'betaActivationPathResult': 'BetaActivationPathResult?',
  'betaActivationPathFinalContext': 'BetaActivationPathContext?',
  'betaFeedbackCaptureRecordReadyPreAudit': 'BetaFeedbackCaptureResult',
  'betaFeedbackCaptureRecordReadyResult': 'BetaFeedbackCaptureResult?',
  'betaFeedbackCapturePostSavePreAudit': 'BetaFeedbackCaptureResult',
  'betaFeedbackCapturePostSaveResult': 'BetaFeedbackCaptureResult?',
  'betaFeedbackCapturePostSaveFinal': 'BetaFeedbackCaptureResult?',
  'betaFeedbackIntelligenceSurfaceOnRecordReady':
      'BetaFeedbackIntelligenceSurface?',
  'betaFeedbackIntelligenceSurfacePostSave': 'BetaFeedbackIntelligenceSurface?',
  'monthlyPrivateReportPreviewPostSave': 'MonthlyPrivateReportPreview?',
  'proPreviewPostSaveResult': 'ProPreviewResult?',
  'betaInviteLoopPostSaveResult': 'BetaInviteLoopResult?',
  'shareableNonPrivateProofResult': 'ShareableProofResult',
  'journalShareProof': 'ShareableArchiveProof?',
  'shareableProof': 'ShareableArchiveProof?',
  'postSaveDailyMirror': 'DailyMirrorResult?',
  'postSaveArchiveHierarchy': 'PostSaveArchiveHierarchy?',
};

const chromeTypes = {
  'ui': 'RecordUiState',
  'betaFeedbackRecordSurfaces': 'List<BetaFeedbackIntelligenceSurface>',
  'bottomInset': 'double',
  'showFirstSessionOnboarding': 'bool',
  'showFirstUseWordingHelper': 'bool',
  'showCloseButton': 'bool',
};

const _primitiveTypes = {'bool', 'int', 'double', 'String', 'dynamic'};

void main() {
  final root = Directory.current.path.endsWith('apps/mobile')
      ? Directory.current
      : Directory('apps/mobile');
  final viewStateFile = File(
    '${root.path}/lib/features/recording/record_surface_view_state.dart',
  );
  final buildContextFile = File(
    '${root.path}/lib/features/recording/recording_build_context.dart',
  );
  final libDir = Directory('${root.path}/lib');

  final typeByField = <String, String>{...knownFieldTypes};
  for (final line in viewStateFile.readAsLinesSync()) {
    final match = RegExp(r'^\s*final\s+(.+?)\s+(\w+);').firstMatch(line);
    if (match == null) continue;
    final field = match.group(2)!;
    final type = match.group(1)!;
    if (type != 'dynamic' && type != 'dynamic /* untyped */') {
      typeByField[field] = type;
    }
  }

  _applyTypes(buildContextFile, typeByField, chromeTypes);
  _applyTypes(viewStateFile, typeByField, const {});

  final exportPaths = _resolveExportPaths(typeByField, chromeTypes, libDir);
  _writeBarrel(
    File('${root.path}/lib/features/recording/record_surface_field_type_exports.dart'),
    exportPaths,
  );

  stdout.writeln(
    'Synced types on view-state and build-context '
    '(${exportPaths.length} type exports)',
  );
}

void _applyTypes(
  File file,
  Map<String, String> typeByField,
  Map<String, String> overrides,
) {
  final lines = file.readAsLinesSync();
  final out = <String>[];
  for (final line in lines) {
    final dynamicMatch = RegExp(
      r'^(\s*)final dynamic(?: /\* untyped \*/)? (\w+);',
    ).firstMatch(line);
    if (dynamicMatch == null) {
      out.add(line);
      continue;
    }
    final field = dynamicMatch.group(2)!;
    final type = overrides[field] ?? typeByField[field] ?? 'dynamic';
    out.add('${dynamicMatch.group(1)}final $type $field;');
  }
  file.writeAsStringSync('${out.join('\n')}\n');
}

Set<String> _collectTypeNames(
  Map<String, String> typeByField,
  Map<String, String> overrides,
) {
  final names = <String>{};
  for (final type in {...typeByField.values, ...overrides.values}) {
    for (final raw in type.split(RegExp(r'[<>?, ]+'))) {
      final name = raw.trim();
      if (name.isEmpty ||
          _primitiveTypes.contains(name) ||
          name == 'List') {
        continue;
      }
      names.add(name);
    }
  }
  return names;
}

List<String> _resolveExportPaths(
  Map<String, String> typeByField,
  Map<String, String> overrides,
  Directory libDir,
) {
  final paths = <String>{};
  final missing = <String>[];

  for (final typeName in _collectTypeNames(typeByField, overrides)) {
    final match = _findTypeDefinition(libDir, typeName);
    if (match == null) {
      missing.add(typeName);
      continue;
    }
    paths.add(match);
  }

  if (missing.isNotEmpty) {
    stderr.writeln('Warning: could not locate definitions for:');
    for (final name in missing..sort()) {
      stderr.writeln('  - $name');
    }
  }

  return paths.toList()..sort();
}

String? _findTypeDefinition(Directory libDir, String typeName) {
  for (final entity in libDir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    if (entity.path.contains('/generated/')) continue;
    final content = entity.readAsStringSync();
    if (RegExp('(?:class|enum|typedef|abstract class) $typeName\\b')
        .hasMatch(content)) {
      final relative = entity.path.split('/lib/').last;
      return 'package:archiveme_mobile/$relative';
    }
  }
  return null;
}

void _writeBarrel(File barrelFile, List<String> exportPaths) {
  final buffer = StringBuffer('''
// GENERATED by tool/sync_record_build_context_types.dart — do not edit by hand.

''');
  for (final exportPath in exportPaths) {
    buffer.writeln("export '$exportPath';");
  }
  barrelFile.writeAsStringSync(buffer.toString());
}
