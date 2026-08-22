import 'dart:io';

import 'package:archiveme_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:archiveme_mobile/features/beta_invite/beta_invite_analytics.dart';
import 'package:archiveme_mobile/features/beta_invite/beta_invite_copy.dart';
import 'package:archiveme_mobile/features/beta_invite/beta_invite_engine.dart';
import 'package:archiveme_mobile/features/beta_invite/beta_invite_model.dart';
import 'package:archiveme_mobile/features/beta_invite/beta_invite_store.dart';
import 'package:archiveme_mobile/features/beta_proof_feedback/beta_proof_feedback_model.dart';
import 'package:archiveme_mobile/features/beta_proof_feedback/beta_proof_feedback_store.dart';
import 'package:archiveme_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:archiveme_mobile/features/surface_priority/surface_priority_model.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:archiveme_mobile/widgets/beta/beta_invite_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs() : super(file: File('test/tmp/beta_invite_loop/unused.json'));

  final Map<String, Map<String, dynamic>> maps = {};

  @override
  Future<Map<String, dynamic>?> readMap(String key) async => maps[key];

  @override
  Future<void> writeMap(String key, Map<String, dynamic> value) async {
    maps[key] = value;
  }
}

BetaInviteLoopContext _context({
  BetaInviteLoopSurface surface = BetaInviteLoopSurface.recordPostSave,
  int entryCount = 3,
  bool betaMissionEnabled = true,
  bool dismissed = false,
  bool hasFirstProof = true,
  BetaInviteLoopTrigger? trigger = BetaInviteLoopTrigger.usefulFeedback,
}) => BetaInviteLoopContext(
  surface: surface,
  source: 'test',
  entryCount: entryCount,
  betaMissionEnabled: betaMissionEnabled,
  dismissed: dismissed,
  hasFirstProof: hasFirstProof,
  trigger: trigger,
);

BetaInviteLoopResult _visibleResult({BetaInviteLoopContext? context}) =>
    BetaInviteLoopEngine.build(context: context ?? _context());

Future<void> _pumpCard(
  WidgetTester tester, {
  required BetaInviteLoopResult result,
  VoidCallback? onDismiss,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: BetaInviteCard.test(result: result, onDismiss: onDismiss),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String? clipboardText;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    clipboardText = null;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (
      call,
    ) async {
      if (call.method == 'Clipboard.setData') {
        clipboardText = (call.arguments as Map)['text'] as String?;
        return null;
      }
      if (call.method == 'Clipboard.getData') {
        return <String, dynamic>{'text': clipboardText};
      }
      return null;
    });
    ArchiveBetaMissionGate.resetForTest();
    ArchiveBetaMissionGate.enabledOverride = true;
    BetaInviteAnalytics.resetForTest();
    BetaInviteLoopDismissStore.invalidateSessionForTest();
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    ArchiveBetaMissionGate.resetForTest();
    BetaInviteAnalytics.resetForTest();
  });

  group('BetaInviteCopy loop', () {
    test('uses loop card copy', () {
      expect(
        BetaInviteCopy.loopCardTitle,
        'Know one person who would test this?',
      );
      expect(
        BetaInviteCopy.loopCardBody,
        'ArchiveMe works best when someone saves a few real moments and comes back when something returns.',
      );
      expect(BetaInviteCopy.loopCta, 'Copy beta invite');
      expect(BetaInviteCopy.loopSecondary, 'Not now');
      expect(
        BetaInviteCopy.loopInviteText,
        'Want to test ArchiveMe? It is a private timeline app. You save small moments when something stands out, and it shows what returns, changes, or fades over time. No daily journal required.',
      );
    });
  });

  group('BetaInviteLoopEngine visibility', () {
    test('hidden before proof', () {
      expect(
        BetaInviteLoopEngine.shouldShowCard(
          _context(hasFirstProof: false, trigger: null),
        ),
        isFalse,
      );
    });

    test('hidden when beta flag false', () {
      expect(
        BetaInviteLoopEngine.shouldShowCard(
          _context(betaMissionEnabled: false),
        ),
        isFalse,
      );
    });

    test('visible after useful feedback', () {
      expect(
        BetaInviteLoopEngine.shouldShowCard(
          _context(),
        ),
        isTrue,
      );
    });

    test('visible after strong proof', () {
      expect(
        BetaInviteLoopEngine.shouldShowCard(
          _context(trigger: BetaInviteLoopTrigger.strongProof),
        ),
        isTrue,
      );
    });

    test('resolves useful feedback trigger from store', () async {
      final prefs = _MemoryPrefs();
      await BetaProofFeedbackStore.resetForTest(prefs);
      await BetaProofFeedbackStore.forPrefs(prefs).saveAnswer(
        surface: BetaProofFeedbackSurface.firstProofPayoff,
        feedbackType: BetaProofFeedbackType.useful,
        entryCount: 3,
      );

      final context = BetaInviteLoopEngine.buildContext(
        surface: BetaInviteLoopSurface.recordPostSave,
        source: 'test',
        entryCount: 3,
        entries: const [],
        betaMissionEnabled: true,
      );

      expect(context.trigger, BetaInviteLoopTrigger.usefulFeedback);
    });

    test('hidden when dismissed for session', () async {
      await BetaInviteLoopEngine.dismissForSession();
      expect(
        BetaInviteLoopEngine.shouldShowCard(
          _context(dismissed: BetaInviteLoopEngine.isDismissed()),
        ),
        isFalse,
      );
    });
  });

  group('BetaInviteCard', () {
    testWidgets('copy button copies generic invite', (tester) async {
      await _pumpCard(tester, result: _visibleResult());

      await tester.tap(find.byKey(const Key('beta_invite_copy')));
      await tester.pumpAndSettle();

      expect(clipboardText, BetaInviteCopy.loopInviteText);
    });

    testWidgets('Not now dismisses through handler', (tester) async {
      var dismissed = false;
      await _pumpCard(
        tester,
        result: _visibleResult(),
        onDismiss: () => dismissed = true,
      );

      await tester.tap(find.byKey(const Key('beta_invite_dismiss')));
      await tester.pump();

      expect(dismissed, isTrue);
    });

    test('no private text or user-specific evidence', () {
      final displayed = BetaInviteCopy.loopDisplayedStrings()
          .join(' ')
          .toLowerCase();
      for (final banned in BetaInviteCopy.loopBannedPrivateTerms) {
        expect(displayed, isNot(contains(banned)));
      }
      for (final banned in BetaInviteCopy.loopBannedEvidenceTerms) {
        expect(displayed, isNot(contains(banned)));
      }
      expect(displayed, isNot(contains('i had no capacity')));
    });
  });

  group('BetaInviteAnalytics', () {
    test('metadata-only analytics', () {
      final events = <String>[];
      final properties = <Map<String, Object>>[];
      BetaInviteAnalytics.captureForTest = (event, props) {
        events.add(event);
        properties.add(props);
      };

      BetaInviteAnalytics.seen(
        source: 'record_post_save',
        surface: 'record_post_save',
        entryCount: 3,
        trigger: BetaInviteLoopTrigger.usefulFeedback.analyticsValue,
      );
      BetaInviteAnalytics.copied(
        source: 'record_post_save',
        surface: 'record_post_save',
        entryCount: 3,
        trigger: BetaInviteLoopTrigger.usefulFeedback.analyticsValue,
      );
      BetaInviteAnalytics.dismissed(
        source: 'record_post_save',
        surface: 'record_post_save',
        entryCount: 3,
        trigger: BetaInviteLoopTrigger.usefulFeedback.analyticsValue,
      );

      expect(events, [
        BetaInviteAnalytics.seenEvent,
        BetaInviteAnalytics.copiedEvent,
        BetaInviteAnalytics.dismissedEvent,
      ]);
      for (final props in properties) {
        expect(props.keys, containsAll(['entry_count', 'source', 'trigger']));
        expect(props.containsKey('product_id'), isFalse);
        expect(props.containsKey('transcript'), isFalse);
        expect(props.containsKey('invite_text'), isFalse);
      }
    });
  });

  group('SurfacePriorityEngine beta invite loop', () {
    test('includes beta invite loop on record post save', () {
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
          returnPayoff: false,
          timelineProofMomentPostSave: false,
          proofSpecificityPostSave: false,
          betaProofFeedback: true,
          betaInviteLoop: true,
          proEvidenceValue: false,
          proLockMoment: false,
          privateReportProBridge: false,
        ),
      );

      expect(
        result.isVisible(
          SurfacePriorityCardKey.betaInviteLoop,
          candidate: true,
        ),
        isTrue,
      );
    });

    test('includes beta invite loop on patterns after report', () {
      final result = SurfacePriorityEngine.auditPatterns(
        entryCount: 5,
        source: 'test',
        candidates: SurfacePriorityCandidates.patterns(
          archiveBeliefSurface: true,
          timelineProofMoment: true,
          archiveTimelineSpine: false,
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
          betaInviteLoop: true,
          proEvidenceValue: false,
          archiveIntelligenceProBridge: false,
          privateReportProBridge: false,
          archiveBackupBridge: false,
          suppressLegacyEducation: false,
        ),
      );

      expect(
        result.isVisible(
          SurfacePriorityCardKey.betaInviteLoop,
          candidate: true,
        ),
        isTrue,
      );
    });
  });
}