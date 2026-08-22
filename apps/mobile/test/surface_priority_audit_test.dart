import 'dart:io';
import 'support/record_screen_library_source.dart';

import 'package:archiveme_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:archiveme_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:archiveme_mobile/features/surface_priority/surface_priority_analytics.dart';
import 'package:archiveme_mobile/features/surface_priority/surface_priority_copy.dart';
import 'package:archiveme_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:archiveme_mobile/features/surface_priority/surface_priority_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final analyticsEvents = <({String event, Map<String, Object> props})>[];

  setUp(() {
    ArchiveBetaMissionGate.resetForTest();
    SurfacePriorityAnalytics.resetForTest();
    SurfacePriorityAnalytics.captureForTest = (event, props) {
      analyticsEvents.add((event: event, props: props));
    };
    analyticsEvents.clear();
  });

  tearDown(SurfacePriorityAnalytics.resetForTest);

  group('SurfacePriorityEngine record ready', () {
    test('never shows more than 1 guidance card', () {
      final result = SurfacePriorityEngine.auditRecordReady(
        entryCount: 5,
        source: 'test',
        candidates: SurfacePriorityCandidates.recordReady(
          firstMomentCapture: false,
          secondMomentReturn: false,
          lowFrictionReturn: true,
          whatToNoticeNext: true,
          betaTodaySummary: true,
          openCapturePromptChips: true,
          captureFreedomLine: true,
          timelineProofMoment: false,
          archiveTimelineSpine: false,
          timelinePositioning: false,
          currentRelevance: false,
          correctionMemory: false,
          notRelevantRecovery: false,
          proofQualityResponse: false,
          evidenceWeighting: false,
          proofSpecificity: false,
          presentDayRelevance: false,
          patternConfidence: false,
          betaTesterReport: false,
          proEvidenceValue: false,
          privateReportProBridge: false,
          suppressLegacyEducation: false,
        ),
      );

      final guidanceVisible = result.visibleCardKeys
          .where(
            (key) =>
                key == SurfacePriorityCardKey.threeMomentCompletion ||
                key == SurfacePriorityCardKey.firstMomentCapture ||
                key == SurfacePriorityCardKey.secondMomentReturn ||
                key == SurfacePriorityCardKey.lowFrictionReturn ||
                key == SurfacePriorityCardKey.whatToNoticeNext ||
                key == SurfacePriorityCardKey.betaTodaySummary ||
                key == SurfacePriorityCardKey.openCapturePromptChips ||
                key == SurfacePriorityCardKey.captureFreedomLine,
          )
          .length;
      expect(guidanceVisible, lessThanOrEqualTo(1));
      expect(result.guidanceSlot, SurfacePriorityCardKey.lowFrictionReturn);
    });

    test(
      'gives three moment completion highest guidance priority for zero entry',
      () {
        final result = SurfacePriorityEngine.auditRecordReady(
          entryCount: 0,
          source: 'test',
          candidates: SurfacePriorityCandidates.recordReady(
            threeMomentCompletion: true,
            firstMomentCapture: true,
            secondMomentReturn: true,
            lowFrictionReturn: true,
            whatToNoticeNext: true,
            betaTodaySummary: true,
            openCapturePromptChips: true,
            captureFreedomLine: true,
            timelineProofMoment: false,
            archiveTimelineSpine: false,
            timelinePositioning: false,
            currentRelevance: false,
            correctionMemory: false,
            notRelevantRecovery: false,
            proofQualityResponse: false,
            evidenceWeighting: false,
            proofSpecificity: false,
            presentDayRelevance: false,
            patternConfidence: false,
            betaTesterReport: false,
            proEvidenceValue: false,
            privateReportProBridge: false,
            suppressLegacyEducation: false,
          ),
        );

        expect(
          result.guidanceSlot,
          SurfacePriorityCardKey.threeMomentCompletion,
        );
        expect(
          result.isVisible(
            SurfacePriorityCardKey.firstMomentCapture,
            candidate: true,
          ),
          isFalse,
        );
      },
    );

    test(
      'gives first moment capture highest guidance priority when three moment inactive',
      () {
        final result = SurfacePriorityEngine.auditRecordReady(
          entryCount: 0,
          source: 'test',
          candidates: SurfacePriorityCandidates.recordReady(
            firstMomentCapture: true,
            secondMomentReturn: true,
            lowFrictionReturn: true,
            whatToNoticeNext: true,
            betaTodaySummary: true,
            openCapturePromptChips: true,
            captureFreedomLine: true,
            timelineProofMoment: false,
            archiveTimelineSpine: false,
            timelinePositioning: false,
            currentRelevance: false,
            correctionMemory: false,
            notRelevantRecovery: false,
            proofQualityResponse: false,
            evidenceWeighting: false,
            proofSpecificity: false,
            presentDayRelevance: false,
            patternConfidence: false,
            betaTesterReport: false,
            proEvidenceValue: false,
            privateReportProBridge: false,
            suppressLegacyEducation: false,
          ),
        );

        expect(result.guidanceSlot, SurfacePriorityCardKey.firstMomentCapture);
        expect(
          result.isVisible(
            SurfacePriorityCardKey.lowFrictionReturn,
            candidate: true,
          ),
          isFalse,
        );
      },
    );

    test(
      'gives three moment completion highest guidance priority for one entry',
      () {
        final result = SurfacePriorityEngine.auditRecordReady(
          entryCount: 1,
          source: 'test',
          candidates: SurfacePriorityCandidates.recordReady(
            threeMomentCompletion: true,
            firstMomentCapture: false,
            secondMomentReturn: true,
            lowFrictionReturn: true,
            whatToNoticeNext: true,
            betaTodaySummary: true,
            openCapturePromptChips: true,
            captureFreedomLine: true,
            timelineProofMoment: false,
            archiveTimelineSpine: false,
            timelinePositioning: false,
            currentRelevance: false,
            correctionMemory: false,
            notRelevantRecovery: false,
            proofQualityResponse: false,
            evidenceWeighting: false,
            proofSpecificity: false,
            presentDayRelevance: false,
            patternConfidence: false,
            betaTesterReport: false,
            proEvidenceValue: false,
            privateReportProBridge: false,
            suppressLegacyEducation: false,
          ),
        );

        expect(
          result.guidanceSlot,
          SurfacePriorityCardKey.threeMomentCompletion,
        );
        expect(
          result.isVisible(
            SurfacePriorityCardKey.secondMomentReturn,
            candidate: true,
          ),
          isFalse,
        );
      },
    );

    test(
      'gives second moment return highest guidance priority when three moment inactive',
      () {
        final result = SurfacePriorityEngine.auditRecordReady(
          entryCount: 1,
          source: 'test',
          candidates: SurfacePriorityCandidates.recordReady(
            firstMomentCapture: false,
            secondMomentReturn: true,
            lowFrictionReturn: true,
            whatToNoticeNext: true,
            betaTodaySummary: true,
            openCapturePromptChips: true,
            captureFreedomLine: true,
            timelineProofMoment: false,
            archiveTimelineSpine: false,
            timelinePositioning: false,
            currentRelevance: false,
            correctionMemory: false,
            notRelevantRecovery: false,
            proofQualityResponse: false,
            evidenceWeighting: false,
            proofSpecificity: false,
            presentDayRelevance: false,
            patternConfidence: false,
            betaTesterReport: false,
            proEvidenceValue: false,
            privateReportProBridge: false,
            suppressLegacyEducation: false,
          ),
        );

        expect(result.guidanceSlot, SurfacePriorityCardKey.secondMomentReturn);
        expect(
          result.isVisible(
            SurfacePriorityCardKey.lowFrictionReturn,
            candidate: true,
          ),
          isFalse,
        );
        expect(
          result.isVisible(
            SurfacePriorityCardKey.whatToNoticeNext,
            candidate: true,
          ),
          isFalse,
        );
      },
    );

    test('never shows more than 1 proof card', () {
      final result = SurfacePriorityEngine.auditRecordReady(
        entryCount: 5,
        source: 'test',
        candidates: SurfacePriorityCandidates.recordReady(
          firstMomentCapture: false,
          secondMomentReturn: false,
          lowFrictionReturn: false,
          whatToNoticeNext: false,
          betaTodaySummary: false,
          openCapturePromptChips: false,
          captureFreedomLine: false,
          timelineProofMoment: true,
          archiveTimelineSpine: true,
          timelinePositioning: true,
          currentRelevance: true,
          correctionMemory: true,
          notRelevantRecovery: false,
          proofQualityResponse: false,
          evidenceWeighting: true,
          proofSpecificity: false,
          presentDayRelevance: false,
          patternConfidence: false,
          betaTesterReport: false,
          proEvidenceValue: false,
          privateReportProBridge: false,
          suppressLegacyEducation: false,
        ),
      );

      final proofVisible = result.visibleCardKeys
          .where(
            (key) =>
                key == SurfacePriorityCardKey.timelineProofMoment ||
                key == SurfacePriorityCardKey.archiveTimelineSpine ||
                key == SurfacePriorityCardKey.timelinePositioning ||
                key == SurfacePriorityCardKey.evidenceWeighting ||
                key == SurfacePriorityCardKey.proofSpecificity ||
                key == SurfacePriorityCardKey.presentDayRelevance ||
                key == SurfacePriorityCardKey.patternConfidence,
          )
          .length;
      expect(proofVisible, lessThanOrEqualTo(1));
      expect(result.proofSlot, SurfacePriorityCardKey.timelineProofMoment);
    });

    test('keeps capture controls primary', () {
      expect(SurfacePriorityCopy.coreRule, contains('capture-first'));
      final source = readRecordScreenLibrarySource();
      expect(source, contains('_buildCaptureEntryActions'));
      expect(
        source.indexOf('_buildCaptureEntryActions'),
        lessThan(
          source.indexOf(
            'ctx.showLowFrictionReturnCard &&\n'
            '            !ctx.firstUseSimplifiedRecord',
          ),
        ),
      );
    });

    test('prefers TimelineProofMoment over ArchiveTimelineSpine', () {
      final result = SurfacePriorityEngine.auditRecordReady(
        entryCount: 5,
        source: 'test',
        candidates: SurfacePriorityCandidates.recordReady(
          firstMomentCapture: false,
          secondMomentReturn: false,
          lowFrictionReturn: false,
          whatToNoticeNext: false,
          betaTodaySummary: false,
          openCapturePromptChips: false,
          captureFreedomLine: false,
          timelineProofMoment: true,
          archiveTimelineSpine: true,
          timelinePositioning: false,
          currentRelevance: false,
          correctionMemory: false,
          notRelevantRecovery: false,
          proofQualityResponse: false,
          evidenceWeighting: false,
          proofSpecificity: false,
          presentDayRelevance: false,
          patternConfidence: false,
          betaTesterReport: true,
          proEvidenceValue: false,
          privateReportProBridge: false,
          suppressLegacyEducation: false,
        ),
      );

      expect(
        result.isVisible(
          SurfacePriorityCardKey.timelineProofMoment,
          candidate: true,
        ),
        isTrue,
      );
      expect(
        result.isVisible(
          SurfacePriorityCardKey.archiveTimelineSpine,
          candidate: true,
        ),
        isFalse,
      );
      expect(
        result.isVisible(
          SurfacePriorityCardKey.betaTesterReport,
          candidate: true,
        ),
        isTrue,
      );
    });

    test('suppresses older education stack when timeline spine visible', () {
      final result = SurfacePriorityEngine.auditRecordReady(
        entryCount: 5,
        source: 'test',
        candidates: SurfacePriorityCandidates.recordReady(
          firstMomentCapture: false,
          secondMomentReturn: false,
          lowFrictionReturn: false,
          whatToNoticeNext: false,
          betaTodaySummary: false,
          openCapturePromptChips: false,
          captureFreedomLine: false,
          timelineProofMoment: false,
          archiveTimelineSpine: true,
          timelinePositioning: true,
          currentRelevance: true,
          correctionMemory: true,
          notRelevantRecovery: false,
          proofQualityResponse: false,
          evidenceWeighting: true,
          proofSpecificity: true,
          presentDayRelevance: true,
          patternConfidence: true,
          betaTesterReport: false,
          proEvidenceValue: false,
          privateReportProBridge: false,
          suppressLegacyEducation: true,
        ),
      );

      expect(result.proofSlot, SurfacePriorityCardKey.archiveTimelineSpine);
      expect(
        result.isVisible(
          SurfacePriorityCardKey.evidenceWeighting,
          candidate: true,
        ),
        isFalse,
      );
      expect(
        result.isVisible(
          SurfacePriorityCardKey.timelinePositioning,
          candidate: true,
        ),
        isFalse,
      );
    });

    test('never shows report with multiple proof cards', () {
      final result = SurfacePriorityEngine.auditRecordReady(
        entryCount: 5,
        source: 'test',
        candidates: SurfacePriorityCandidates.recordReady(
          firstMomentCapture: false,
          secondMomentReturn: false,
          lowFrictionReturn: true,
          whatToNoticeNext: false,
          betaTodaySummary: false,
          openCapturePromptChips: false,
          captureFreedomLine: false,
          timelineProofMoment: true,
          archiveTimelineSpine: true,
          timelinePositioning: false,
          currentRelevance: false,
          correctionMemory: false,
          notRelevantRecovery: false,
          proofQualityResponse: false,
          evidenceWeighting: false,
          proofSpecificity: false,
          presentDayRelevance: false,
          patternConfidence: false,
          betaTesterReport: true,
          proEvidenceValue: false,
          privateReportProBridge: false,
          suppressLegacyEducation: false,
        ),
      );

      expect(
        result.isVisible(
          SurfacePriorityCardKey.betaTesterReport,
          candidate: true,
        ),
        isFalse,
      );
    });
  });

  group('SurfacePriorityEngine record post save', () {
    test('hides guidance cards', () {
      final result = SurfacePriorityEngine.auditRecordPostSave(
        entryCount: 3,
        source: 'test',
        candidates: SurfacePriorityCandidates.recordPostSave(
          lowFrictionReturn: true,
          whatToNoticeNext: true,
          betaTodaySummary: true,
          openCapturePromptChips: true,
          captureFreedomLine: true,
          firstProofPayoff: true,
          whatChanged: false,
          returnPayoff: false,
          timelineProofMomentPostSave: true,
          proofSpecificityPostSave: true,
          betaProofFeedback: true,
          proEvidenceValue: true,
          proLockMoment: false,
          privateReportProBridge: false,
        ),
      );

      expect(
        result.isVisible(
          SurfacePriorityCardKey.lowFrictionReturn,
          candidate: true,
        ),
        isFalse,
      );
      expect(
        result.hiddenReasons,
        contains(SurfacePriorityCopy.hiddenReasonPostSaveGuidance),
      );
    });

    test('FirstProofPayoff wins', () {
      final result = SurfacePriorityEngine.auditRecordPostSave(
        entryCount: 3,
        source: 'test',
        candidates: SurfacePriorityCandidates.recordPostSave(
          lowFrictionReturn: false,
          whatToNoticeNext: false,
          betaTodaySummary: false,
          openCapturePromptChips: false,
          captureFreedomLine: false,
          firstProofPayoff: true,
          whatChanged: false,
          returnPayoff: true,
          timelineProofMomentPostSave: true,
          proofSpecificityPostSave: true,
          betaProofFeedback: true,
          proEvidenceValue: false,
          proLockMoment: false,
          privateReportProBridge: false,
        ),
      );

      expect(
        result.isVisible(
          SurfacePriorityCardKey.firstProofPayoff,
          candidate: true,
        ),
        isTrue,
      );
      expect(
        result.isVisible(SurfacePriorityCardKey.returnPayoff, candidate: true),
        isFalse,
      );
    });

    test('WhatChanged wins', () {
      final result = SurfacePriorityEngine.auditRecordPostSave(
        entryCount: 3,
        source: 'test',
        candidates: SurfacePriorityCandidates.recordPostSave(
          lowFrictionReturn: false,
          whatToNoticeNext: false,
          betaTodaySummary: false,
          openCapturePromptChips: false,
          captureFreedomLine: false,
          firstProofPayoff: true,
          whatChanged: true,
          returnPayoff: true,
          timelineProofMomentPostSave: true,
          proofSpecificityPostSave: true,
          betaProofFeedback: true,
          proEvidenceValue: true,
          proLockMoment: true,
          privateReportProBridge: true,
        ),
      );

      expect(
        result.isVisible(SurfacePriorityCardKey.whatChanged, candidate: true),
        isTrue,
      );
      expect(
        result.isVisible(
          SurfacePriorityCardKey.firstProofPayoff,
          candidate: true,
        ),
        isFalse,
      );
    });
  });

  group('SurfacePriorityEngine patterns', () {
    test('shows timeline-first order', () {
      final result = SurfacePriorityEngine.auditPatterns(
        entryCount: 5,
        source: 'test',
        candidates: SurfacePriorityCandidates.patterns(
          archiveBeliefSurface: true,
          timelineProofMoment: true,
          archiveTimelineSpine: true,
          betaTesterReport: false,
          correctionMemory: false,
          notRelevantRecovery: false,
          proofQualityResponse: false,
          patternConfidence: false,
          evidenceWeighting: false,
          currentRelevance: false,
          proofSpecificity: false,
          presentDayRelevance: false,
          timelinePositioning: false,
          proEvidenceValue: false,
          archiveIntelligenceProBridge: false,
          privateReportProBridge: false,
          archiveBackupBridge: false,
          suppressLegacyEducation: false,
        ),
      );

      final beliefIndex = result.visibleCardKeys.indexOf(
        SurfacePriorityCardKey.archiveBeliefSurface,
      );
      final proofIndex = result.visibleCardKeys.indexOf(
        SurfacePriorityCardKey.timelineProofMoment,
      );
      final spineIndex = result.visibleCardKeys.indexOf(
        SurfacePriorityCardKey.archiveTimelineSpine,
      );
      expect(beliefIndex, lessThan(proofIndex));
      expect(proofIndex, lessThan(spineIndex));
    });

    test('allows BetaTesterReport below timeline', () {
      final result = SurfacePriorityEngine.auditPatterns(
        entryCount: 5,
        source: 'test',
        candidates: SurfacePriorityCandidates.patterns(
          archiveBeliefSurface: true,
          timelineProofMoment: true,
          archiveTimelineSpine: true,
          betaTesterReport: true,
          correctionMemory: true,
          notRelevantRecovery: false,
          proofQualityResponse: false,
          patternConfidence: true,
          evidenceWeighting: true,
          currentRelevance: true,
          proofSpecificity: true,
          presentDayRelevance: true,
          timelinePositioning: true,
          proEvidenceValue: false,
          archiveIntelligenceProBridge: false,
          privateReportProBridge: false,
          archiveBackupBridge: false,
          suppressLegacyEducation: false,
        ),
      );

      expect(
        result.isVisible(
          SurfacePriorityCardKey.betaTesterReport,
          candidate: true,
        ),
        isTrue,
      );
      final reportIndex = result.visibleCardKeys.indexOf(
        SurfacePriorityCardKey.betaTesterReport,
      );
      final spineIndex = result.visibleCardKeys.indexOf(
        SurfacePriorityCardKey.archiveTimelineSpine,
      );
      expect(reportIndex, greaterThan(spineIndex));
    });

    test('Pro bridge appears after proof/report', () {
      final result = SurfacePriorityEngine.auditPatterns(
        entryCount: 5,
        source: 'test',
        candidates: SurfacePriorityCandidates.patterns(
          archiveBeliefSurface: true,
          timelineProofMoment: true,
          archiveTimelineSpine: true,
          betaTesterReport: true,
          correctionMemory: false,
          notRelevantRecovery: false,
          proofQualityResponse: false,
          patternConfidence: false,
          evidenceWeighting: false,
          currentRelevance: false,
          proofSpecificity: false,
          presentDayRelevance: false,
          timelinePositioning: false,
          proBridgeVisibility: true,
          proEvidenceValue: true,
          archiveIntelligenceProBridge: true,
          privateReportProBridge: true,
          archiveBackupBridge: true,
          suppressLegacyEducation: false,
        ),
      );

      expect(result.proSlot, SurfacePriorityCardKey.proBridgeVisibility);
      final proIndex = result.visibleCardKeys.indexOf(
        SurfacePriorityCardKey.proBridgeVisibility,
      );
      final reportIndex = result.visibleCardKeys.indexOf(
        SurfacePriorityCardKey.betaTesterReport,
      );
      expect(proIndex, greaterThan(reportIndex));
    });

    test('allows only one detail card', () {
      final result = SurfacePriorityEngine.auditPatterns(
        entryCount: 5,
        source: 'test',
        candidates: SurfacePriorityCandidates.patterns(
          archiveBeliefSurface: false,
          timelineProofMoment: false,
          archiveTimelineSpine: false,
          betaTesterReport: false,
          correctionMemory: true,
          notRelevantRecovery: false,
          proofQualityResponse: false,
          patternConfidence: true,
          evidenceWeighting: true,
          currentRelevance: true,
          proofSpecificity: true,
          presentDayRelevance: true,
          timelinePositioning: true,
          proEvidenceValue: false,
          archiveIntelligenceProBridge: false,
          privateReportProBridge: false,
          archiveBackupBridge: false,
          suppressLegacyEducation: false,
        ),
      );

      final detailVisible = result.visibleCardKeys
          .where(
            (key) =>
                key == SurfacePriorityCardKey.correctionMemory ||
                key == SurfacePriorityCardKey.patternConfidence ||
                key == SurfacePriorityCardKey.evidenceWeighting,
          )
          .length;
      expect(detailVisible, lessThanOrEqualTo(1));
      expect(
        result.visibleCardKeys,
        contains(SurfacePriorityCardKey.correctionMemory),
      );
    });

    test(
      'proof quality response wins correction slot over not relevant recovery',
      () {
        final result = SurfacePriorityEngine.auditRecordReady(
          entryCount: 4,
          source: 'test',
          candidates: SurfacePriorityCandidates.recordReady(
            firstMomentCapture: false,
            secondMomentReturn: false,
            lowFrictionReturn: false,
            whatToNoticeNext: false,
            betaTodaySummary: false,
            openCapturePromptChips: false,
            captureFreedomLine: false,
            timelineProofMoment: true,
            archiveTimelineSpine: false,
            timelinePositioning: false,
            currentRelevance: false,
            correctionMemory: false,
            notRelevantRecovery: true,
            proofQualityResponse: true,
            evidenceWeighting: false,
            proofSpecificity: false,
            presentDayRelevance: false,
            patternConfidence: false,
            betaTesterReport: false,
            proEvidenceValue: false,
            privateReportProBridge: false,
            suppressLegacyEducation: false,
          ),
        );

        expect(
          result.correctionSlot,
          SurfacePriorityCardKey.proofQualityResponse,
        );
        expect(
          result.isVisible(
            SurfacePriorityCardKey.proofQualityResponse,
            candidate: true,
          ),
          isTrue,
        );
        expect(
          result.isVisible(
            SurfacePriorityCardKey.notRelevantRecovery,
            candidate: true,
          ),
          isFalse,
        );
      },
    );
  });

  group('SurfacePriorityEngine paywall', () {
    test('has one paid reason', () {
      final result = SurfacePriorityEngine.auditPaywall(
        entryCount: 5,
        source: 'test',
        candidates: SurfacePriorityCandidates.paywall(
          primaryReason: true,
          secondaryReason: true,
        ),
      );

      expect(
        SurfacePriorityCopy.paidReason,
        'Pro keeps the longer proof trail over time.',
      );
      expect(result.visibleCardCount, 1);
      expect(
        result.isVisible(
          SurfacePriorityCardKey.paywallPrimaryReason,
          candidate: true,
        ),
        isTrue,
      );
      expect(
        result.isVisible(
          SurfacePriorityCardKey.paywallSecondaryReason,
          candidate: true,
        ),
        isFalse,
      );
    });
  });

  group('SurfacePriorityAnalytics', () {
    test('metadata-only analytics', () {
      final result = SurfacePriorityEngine.auditRecordReady(
        entryCount: 4,
        source: 'test',
        candidates: SurfacePriorityCandidates.recordReady(
          firstMomentCapture: false,
          secondMomentReturn: false,
          lowFrictionReturn: true,
          whatToNoticeNext: false,
          betaTodaySummary: false,
          openCapturePromptChips: false,
          captureFreedomLine: false,
          timelineProofMoment: true,
          archiveTimelineSpine: false,
          timelinePositioning: false,
          currentRelevance: false,
          correctionMemory: false,
          notRelevantRecovery: false,
          proofQualityResponse: false,
          evidenceWeighting: false,
          proofSpecificity: false,
          presentDayRelevance: false,
          patternConfidence: false,
          betaTesterReport: false,
          proEvidenceValue: false,
          privateReportProBridge: false,
          suppressLegacyEducation: false,
        ),
      );
      SurfacePriorityAnalytics.seen(result: result);

      expect(analyticsEvents, isNotEmpty);
      final seen = analyticsEvents.firstWhere(
        (event) => event.event == SurfacePriorityAnalytics.seenEvent,
      );
      expect(
        seen.props.keys,
        containsAll([
          'source',
          'surface',
          'entry_count',
          'visible_card_count',
          'suppressed_card_count',
          'proof_card_key',
          'guidance_card_key',
        ]),
      );
      expect(seen.props.keys, isNot(contains('transcript')));
      expect(seen.props.keys, isNot(contains('body')));
    });
  });

  group('Surface priority copy guard', () {
    test('no therapy/medical claims', () {
      for (final line in SurfacePriorityCopy.allVisibleStrings()) {
        expect(
          ProofSurfaceAdviceGuard.passes(line),
          isTrue,
          reason: 'failed on: $line',
        );
      }
    });

    test('no transcript/body/private text in analytics', () {
      final source = File(
        'lib/features/surface_priority/surface_priority_analytics.dart',
      ).readAsStringSync().toLowerCase();
      expect(source, isNot(contains('transcript')));
      expect(source, isNot(contains('entry_id')));
    });
  });

  group('Surface priority integration', () {
    test('record screen references SurfacePriorityEngine', () {
      final source = readRecordScreenLibrarySource();
      expect(source, contains('SurfacePriorityEngine.auditRecordReady'));
      expect(source, contains('SurfacePriorityEngine.auditRecordPostSave'));
    });

    test('patterns audit remains defined on SurfacePriorityEngine', () {
      final source = File(
        'lib/features/surface_priority/surface_priority_engine.dart',
      ).readAsStringSync();
      expect(source, contains('static SurfacePriorityResult auditPatterns'));
      expect(source, contains('SurfacePriorityCardKey'));
    });
  });
}