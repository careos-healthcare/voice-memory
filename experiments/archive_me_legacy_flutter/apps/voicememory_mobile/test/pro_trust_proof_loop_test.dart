import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/features/action_items/action_item_store.dart';
import 'package:voicememory_mobile/features/memory/keep_exact_details.dart';
import 'package:voicememory_mobile/features/memory/memory_scope.dart';
import 'package:voicememory_mobile/features/memory/memory_scope_policy.dart';
import 'package:voicememory_mobile/features/trust/aha_proof_share_eligibility.dart';
import 'package:voicememory_mobile/features/trust/archive_trust_receipt.dart';
import 'package:voicememory_mobile/features/pro_single_promise/pro_single_promise_copy.dart';
import 'package:voicememory_mobile/features/trust/pro_trust_copy.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/aha/aha_moment_feedback_row.dart';
import 'package:voicememory_mobile/widgets/share/aha_proof_share_card.dart';
import 'package:voicememory_mobile/widgets/trust/archive_private_receipt_card.dart';
import 'package:voicememory_mobile/widgets/trust/pro_value_clarity_card.dart';
import 'package:voicememory_mobile/features/aha/aha_moment_candidate.dart';
import 'package:voicememory_mobile/features/memory/memory_authority_frame.dart';

class _Event {
  const _Event(this.name, this.properties);
  final String name;
  final Map<String, Object> properties;
}

final List<_Event> _events = [];

const _privateNote = 'Call dentist about crown follow-up today';

const _bannedWords = [
  'always',
  'never',
  'proves',
  'definitely',
  'diagnosis',
  'diagnose',
  'therapy',
  'treatment',
  'fixed',
  'broken',
  'problem',
  'failure',
  'lazy',
  'weak',
  'must',
  'should',
  'surveillance',
  'spying',
  'tracking',
  'unlock premium',
  'VoiceMemory',
];

JournalEntry _entry({
  required String id,
  bool keepExactDetails = false,
  bool isPinned = false,
  String? archivePackId,
  String? archiveThreadId,
  bool treatAsNew = false,
  bool keepSeparate = false,
}) => JournalEntry(
  id: id,
  createdAt: DateTime(2026, 6, 12),
  transcript: _privateNote,
  durationSeconds: 20,
  reflection: const Reflection(
    mood: 'thoughtful',
    emotionalIntensity: 2,
    recurringThemes: ['work'],
    exactLanguagePattern: 'pattern',
    concreteObservation: 'Observation text.',
    repeatedSignal: 'signal',
  ),
  keepExactDetails: keepExactDetails,
  isPinned: isPinned,
  archivePackId: archivePackId,
  archiveThreadId: archiveThreadId,
  treatAsNew: treatAsNew,
  keepSeparate: keepSeparate,
);

AhaMomentCandidate _ahaCandidate() => AhaMomentCandidate(
  entryCount: 2,
  eligibleEntryCount: 2,
  memoryScope: MemoryScope.automatic.id,
  priorityBand: 'normal',
  authorityState: MemoryAuthorityState.current,
  useCautiousCopy: false,
);

void _reset() {
  MemoryScopePolicy.resetForTest();
  MemoryScopePolicy.scope = MemoryScope.automatic;
  ArchiveTrustReceipt.resetForTest();
  AhaProofShareEligibility.resetForTest();
  KeepExactDetails.resetSessionForTest();
  _events.clear();
  ActivationFunnelAnalytics.resetForTest();
  ActivationFunnelAnalytics.captureForTest(
    (event, properties) => _events.add(_Event(event, properties)),
  );
}

void main() {
  setUp(_reset);

  group('Trust receipt', () {
    test('appears after important save', () {
      ArchiveTrustReceipt.noteSave(
        entry: _entry(id: 'e1', keepExactDetails: true),
        entryCount: 1,
      );
      expect(ArchiveTrustReceipt.shouldShow(entryCount: 1), isTrue);
    });

    test('does not spam every save', () {
      ArchiveTrustReceipt.noteSave(
        entry: _entry(id: 'e1', keepExactDetails: true),
        entryCount: 1,
      );
      ArchiveTrustReceipt.markShown();
      ArchiveTrustReceipt.noteSave(
        entry: _entry(id: 'e2', isPinned: true),
        entryCount: 2,
      );
      expect(ArchiveTrustReceipt.shouldShow(entryCount: 2), isFalse);
    });

    test('does not appear before first save', () {
      ArchiveTrustReceipt.noteSave(
        entry: _entry(id: 'e1', keepExactDetails: true),
        entryCount: 0,
      );
      expect(ArchiveTrustReceipt.shouldShow(entryCount: 0), isFalse);
    });

    test('receipt copy is exact', () {
      expect(ProTrustCopy.receiptTitle, 'Saved privately');
      expect(
        ProTrustCopy.receiptBody,
        'You control whether this connects to your archive, stays separate, '
        'or gets exported.',
      );
      expect(ProTrustCopy.receiptReviewCta, 'Review controls');
      expect(ProTrustCopy.receiptNotNow, 'Not now');
    });

    testWidgets('Review controls opens settings', (tester) async {
      ArchiveTrustReceipt.noteSave(
        entry: _entry(id: 'e1', keepExactDetails: true),
        entryCount: 1,
      );
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) =>
                ArchivePrivateReceiptCard(entryCount: 1, onDismiss: () {}),
          ),
          GoRoute(
            path: '/settings',
            builder: (_, _) =>
                const Scaffold(body: Text('Settings memory controls')),
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('archive_private_receipt_review')));
      await tester.pumpAndSettle();

      expect(find.text('Settings memory controls'), findsOneWidget);
      expect(
        _events.map((e) => e.name),
        contains(ActivationFunnelAnalytics.archivePrivateReceiptReviewTapped),
      );
    });
  });

  group('Pro value clarity', () {
    test('copy is exact', () {
      expect(ProTrustCopy.proTitle, ProSinglePromiseCopy.headline);
      expect(
        ProTrustCopy.proBody,
        'Unlock deeper history, saved evidence, and continuity as your '
        'archive grows.',
      );
      expect(ProTrustCopy.proBulletFind, 'Find important entries faster');
      expect(ProTrustCopy.proBulletExport, 'Export what matters');
      expect(
        ProTrustCopy.proBulletContext,
        'Keep archive context useful over time',
      );
      expect(ProTrustCopy.proCta, 'See Pro');
      expect(ProTrustCopy.proSecondary, 'Not now');
    });

    test('does not falsely gate free Search/Pins in copy', () {
      final corpus = ProTrustCopy.all.join(' ').toLowerCase();
      expect(corpus.contains('search is pro'), isFalse);
      expect(corpus.contains('pin is pro'), isFalse);
      expect(corpus.contains('pins are pro'), isFalse);
      expect(corpus.contains('unlock premium'), isFalse);
    });

    testWidgets('card does not interrupt recording', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Column(
              children: [
                const Text('Recording in progress'),
                ProValueClarityCard(
                  entryCount: 1,
                  source: 'record',
                  onSeePro: () {},
                  onNotNow: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Recording in progress'), findsOneWidget);
      expect(find.byKey(const Key('pro_value_clarity_card')), findsOneWidget);
    });

    testWidgets('fires clarity analytics', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ProValueClarityCard(
              entryCount: 2,
              source: 'archive',
              onSeePro: () {},
              onNotNow: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        _events.map((e) => e.name),
        contains(ActivationFunnelAnalytics.proValueClaritySeen),
      );
    });
  });

  group('Aha proof share', () {
    test('appears only after eligible aha useful feedback', () {
      expect(AhaProofShareEligibility.shouldShow, isFalse);
      AhaProofShareEligibility.markEligibleFromAhaUseful();
      expect(AhaProofShareEligibility.shouldShow, isTrue);
    });

    test('share proof contains no raw note text', () {
      expect(ProTrustCopy.shareTextTemplate.contains(_privateNote), isFalse);
      expect(ProTrustCopy.shareBody.contains(_privateNote), isFalse);
    });

    test('share proof includes ArchiveMe branding', () {
      expect(ProTrustCopy.shareTextTemplate, contains('ArchiveMe'));
      expect(ProTrustCopy.shareTextTemplate, isNot(contains('VoiceMemory')));
      expect(
        ProTrustCopy.shareTextTemplate.toLowerCase(),
        isNot(contains('chatgpt')),
      );
      expect(
        ProTrustCopy.shareTextTemplate.toLowerCase(),
        isNot(contains('openai')),
      );
    });

    testWidgets('share proof requires user tap', (tester) async {
      AhaProofShareEligibility.markEligibleFromAhaUseful();
      var shared = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: AhaProofShareCard(
              entryCount: 2,
              onDismiss: () {},
              onShare: (text) async {
                shared = true;
                expect(text, ProTrustCopy.shareTextTemplate);
              },
            ),
          ),
        ),
      );
      await tester.pump();
      expect(shared, isFalse);
      await tester.tap(find.byKey(const Key('aha_proof_share_cta')));
      await tester.pump();
      expect(shared, isTrue);
      expect(
        _events.map((e) => e.name),
        contains(ActivationFunnelAnalytics.ahaProofShareTapped),
      );
    });

    testWidgets('useful aha feedback enables share card', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: AhaMomentFeedbackRow(
              candidate: _ahaCandidate(),
              onFeedback: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('aha_moment_useful')));
      await tester.pump();
      expect(AhaProofShareEligibility.shouldShow, isTrue);
    });
  });

  group('Action item trust signal', () {
    test('action item creation can qualify receipt', () async {
      final dir = await Directory.systemTemp.createTemp('trust_action_item');
      final prefs = await MobilePrefsStore.open('${dir.path}/prefs.json');
      final store = ActionItemStore.forPrefs(prefs);
      ArchiveTrustReceipt.noteActionItemCreated(entryCount: 1);
      expect(ArchiveTrustReceipt.shouldShow(entryCount: 1), isTrue);
      await store.create(sourceEntryId: 'e1', title: 'Follow up');
      dir.deleteSync(recursive: true);
    });
  });

  group('Analytics privacy', () {
    test('payload contains no private content', () {
      ArchiveTrustReceipt.noteSave(
        entry: _entry(id: 'e1', keepExactDetails: true),
        entryCount: 1,
      );
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.archivePrivateReceiptSeen,
        entryCount: 1,
        source: 'test',
        stage: ProTrustStage.keepExact,
        memoryScope: MemoryScope.automatic.id,
      );
      final payloads = _events
          .map((e) => '${e.name} ${e.properties}')
          .join('\n');
      expect(payloads.contains(_privateNote), isFalse);
      for (final event in _events) {
        expect(
          event.properties.keys.toSet().difference(
            ActivationFunnelAnalytics.allowedPropertyKeys,
          ),
          isEmpty,
        );
      }
    });
  });

  group('Copy guardrails', () {
    test('no VoiceMemory in consumer copy', () {
      for (final line in ProTrustCopy.all) {
        expect(line.contains('VoiceMemory'), isFalse);
      }
    });

    test('banned-word sweep', () {
      final corpus = ProTrustCopy.all.join('\n').toLowerCase();
      for (final word in _bannedWords) {
        expect(
          RegExp('\\b${RegExp.escape(word.toLowerCase())}\\b').hasMatch(corpus),
          isFalse,
          reason: 'banned word: $word',
        );
      }
    });
  });
}
