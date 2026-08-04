import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_export/archive_export_pack.dart';
import 'package:voicememory_mobile/features/beta_feedback/beta_feedback_models.dart';
import 'package:voicememory_mobile/features/beta_invite/beta_invite_copy.dart';
import 'package:voicememory_mobile/features/beta_invite/beta_invite_engine.dart';
import 'package:voicememory_mobile/features/beta_invite/beta_invite_models.dart';
import 'package:voicememory_mobile/features/beta_invite/beta_invite_store.dart';
import 'package:voicememory_mobile/features/beta_outcomes/beta_outcomes_engine.dart';
import 'package:voicememory_mobile/features/beta_outcomes/beta_outcomes_models.dart';
import 'package:voicememory_mobile/features/pressure_retention/shareable_archive_proof_engine.dart';
import 'package:voicememory_mobile/features/pro_interest/pro_interest_models.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/security/sensitive_screen_guard.dart';
import 'package:voicememory_mobile/features/share/archive_share_actions.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/screens/support_feedback_screen.dart';

const _bannedWords = [
  'diagnosis',
  'symptom',
  'therapy',
  'mental health',
  'medical',
  'streak',
  'guilt',
  'certain',
  'addictive',
  'limited time',
  'subscribe now',
  'buy now',
  'must upgrade',
  'share to unlock',
  'pro is active',
  'purchases are available',
];

const _forbiddenPurchaseCtas = [
  'Buy now',
  'Subscribe now',
  'Start trial',
  'Limited time',
];

JournalEntry _entry(String id, {String? transcript}) => JournalEntry(
  id: id,
  createdAt: DateTime(2026, 6, 12, 12),
  transcript:
      transcript ??
      'I felt pressure at work before saying yes again even when I was tired today.',
  durationSeconds: 30,
  localAudioPath: '/tmp/$id.m4a',
  reflection: const Reflection(
    mood: 'neutral',
    emotionalIntensity: 2,
    recurringThemes: ['work'],
    exactLanguagePattern: '',
    concreteObservation: 'Work pressure showed up in this moment.',
    repeatedSignal: '',
  ),
);

List<JournalEntry> _entries(int count) =>
    List.generate(count, (i) => _entry('e$i'));

void _expectNoBannedCopy(Iterable<String> visible) {
  for (final text in visible) {
    final lower = text.toLowerCase();
    for (final word in _bannedWords) {
      expect(
        lower,
        isNot(contains(word)),
        reason: 'must not contain "$word" in "$text"',
      );
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const inviteEngine = BetaInviteEngine();
  const outcomesEngine = BetaOutcomesEngine();

  group('Beta invite copy', () {
    test('includes clear simple positioning', () {
      expect(
        BetaInviteCopy.allVisibleCopy(),
        contains(BetaInviteCopy.corePositioning),
      );
      expect(BetaInviteCopy.corePositioning, contains('keeps returning'));
    });

    test('all five invite variants exist', () {
      expect(BetaInviteVariantId.values.length, 5);
      for (final variant in BetaInviteVariantId.values) {
        expect(BetaInviteCopy.shortInvite(variant), isNotEmpty);
        expect(BetaInviteCopy.longInvite(variant), isNotEmpty);
      }
    });

    test('short invite mentions saving a few moments', () {
      for (final variant in BetaInviteVariantId.values) {
        expect(
          BetaInviteCopy.shortInvite(variant).toLowerCase(),
          anyOf(contains('few'), contains('small moment')),
        );
      }
    });

    test('tester task says open Archive after third moment', () {
      expect(
        BetaInviteCopy.testerTask,
        contains('After the third, open Archive'),
      );
    });

    test('copy warns not to share private entries', () {
      expect(
        BetaInviteCopy.allVisibleCopy(),
        contains(BetaInviteCopy.privacyReminder),
      );
      expect(
        BetaInviteCopy.privacyReminder,
        contains('Do not share private entries'),
      );
    });

    test('copy does not include raw journal text', () {
      const privateSnippet = 'Private boss conversation about burnout';
      for (final text in BetaInviteCopy.allVisibleCopy()) {
        expect(text, isNot(contains(privateSnippet)));
      }
      for (final variant in BetaInviteVariantId.values) {
        expect(
          BetaInviteCopy.fullInvite(variant),
          isNot(contains(privateSnippet)),
        );
      }
    });

    test('uses ArchiveMe not VoiceMemory', () {
      final joined = BetaInviteCopy.allVisibleCopy().join('\n');
      expect(joined, contains('ArchiveMe'));
      expect(joined, isNot(contains('VoiceMemory')));
    });

    test('does not include Buy now or Subscribe now copy', () {
      final joined = BetaInviteCopy.allVisibleCopy().join('\n');
      for (final cta in _forbiddenPurchaseCtas) {
        expect(joined, isNot(contains(cta)));
      }
    });

    test(
      'avoids therapy diagnosis certainty streak guilt pressure language',
      () {
        _expectNoBannedCopy(BetaInviteCopy.allVisibleCopy());
      },
    );
  });

  group('Beta invite store', () {
    late Directory tempDir;
    late MobilePrefsStore prefs;
    late BetaInviteStore store;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('beta_invite_test_');
      prefs = await MobilePrefsStore.open('${tempDir.path}/prefs.json');
      store = BetaInviteStore(prefs);
      await BetaInviteStore.resetForTest();
    });

    tearDown(() async {
      await BetaInviteStore.resetForTest();
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('local copy counts persist per variant', () async {
      await store.recordShortCopy(BetaInviteVariantId.general);
      await store.recordFullCopy(BetaInviteVariantId.general);
      await store.recordTaskCopy(BetaInviteVariantId.workPatterns);

      final loaded = await store.load();
      expect(loaded.statsFor(BetaInviteVariantId.general).shortCopiedCount, 1);
      expect(loaded.statsFor(BetaInviteVariantId.general).fullCopiedCount, 1);
      expect(
        loaded.statsFor(BetaInviteVariantId.workPatterns).taskCopiedCount,
        1,
      );
      expect(loaded.totalCopiedCount, 3);
      expect(loaded.lastVariantId, BetaInviteVariantId.workPatterns);
      expect(loaded.testerTaskCopied, isTrue);

      final prefsRaw = await File('${tempDir.path}/prefs.json').readAsString();
      expect(prefsRaw, contains('archiveBetaInviteCopies'));
      expect(prefsRaw, isNot(contains('Save 3 moments')));
    });
  });

  group('Beta Outcomes beta invite integration', () {
    test('shows invite copied count and last variant', () {
      final stats = BetaInviteCopyStats(
        records: {
          BetaInviteVariantId.founderCreator: BetaInviteVariantStats(
            variantId: BetaInviteVariantId.founderCreator,
            shortCopiedCount: 2,
            taskCopiedCount: 1,
          ),
        },
        lastVariantId: BetaInviteVariantId.founderCreator,
      );
      final snapshot = outcomesEngine.build(
        BetaOutcomesInput(
          savedMomentCount: 4,
          usableEvidenceCount: 3,
          depthLevelLabel: 'Early archive',
          watchThemesCount: 1,
          returnRitualSet: false,
          feedbackState: BetaFeedbackState.empty,
          shareProofReady: false,
          proInterestState: ProInterestState.empty,
          betaInviteCopyStats: stats,
        ),
      );
      expect(snapshot.betaInviteCopiedCount, 3);
      expect(
        snapshot.betaInviteLastVariantLabel,
        BetaInviteCopy.variantFounderCreatorTitle,
      );
      expect(snapshot.betaInviteTaskCopied, isTrue);
    });

    test('outcomes summary uses none yet when no copies', () {
      final summary = inviteEngine.outcomesSummary(BetaInviteCopyStats.empty);
      expect(summary.totalCopiedCount, 0);
      expect(summary.lastVariantLabel, BetaInviteCopy.betaOutcomesNoneLabel);
      expect(summary.testerTaskCopied, isFalse);
    });
  });

  group('Beta invite privacy exclusions', () {
    test('export pack excludes beta invite content', () {
      final pack = ArchiveExportPackEngine.build(
        entries: _entries(5),
        exportedAt: DateTime.utc(2026, 6, 15),
      );
      expect(pack.plainText, isNot(contains(BetaInviteCopy.screenTitle)));
      expect(pack.plainText, isNot(contains('Invite a beta tester')));
      expect(pack.plainText, isNot(contains('archiveBetaInviteCopies')));
    });

    test('share-safe proof excludes beta invite content', () {
      final proof = const ShareableArchiveProofEngine().buildFromJournal(
        entries: _entries(5),
      );
      expect(proof.shareText, isNot(contains(BetaInviteCopy.screenTitle)));
      expect(proof.shareText, isNot(contains('Invite a beta tester')));
    });
  });

  group('Beta invite routing and links', () {
    test('route is sensitive and linked from Support and Beta Outcomes', () {
      final router = File('lib/router/app_router.dart').readAsStringSync();
      final support = File(
        'lib/screens/support_feedback_screen.dart',
      ).readAsStringSync();
      final outcomes = File(
        'lib/screens/beta_outcomes_screen.dart',
      ).readAsStringSync();
      expect(router, contains("path: '/beta-invite-pack'"));
      expect(SensitiveRoutes.isSensitiveRoute('/beta-invite-pack'), isTrue);
      expect(support, contains("context.push('/beta-invite-pack')"));
      expect(outcomes, contains("context.push('/beta-invite-pack')"));
    });

    testWidgets('Support & feedback links to beta invite pack', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const SupportFeedbackScreen(),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const Key('support_feedback_open_beta_invite_pack')),
        findsOneWidget,
      );
      expect(find.text(BetaInviteCopy.openBetaInviteButton), findsOneWidget);
    });

    test('invite screen includes positioning variants and copy actions', () {
      final screen = File(
        'lib/screens/beta_invite_pack_screen.dart',
      ).readAsStringSync();
      expect(screen, contains('beta_invite_pack_screen'));
      expect(screen, contains('beta_invite_pack_positioning'));
      expect(screen, contains('BetaInviteCopy.corePositioning'));
      expect(screen, contains('beta_invite_copy_short'));
      expect(screen, contains('beta_invite_copy_full'));
      expect(screen, contains('beta_invite_copy_task'));
      expect(screen, contains('beta_invite_pack_privacy_reminder'));
      expect(screen, contains(r'beta_invite_variant_${variant.name}'));
    });

    test('copy short invite action works', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'beta_invite_copy_',
      );
      final prefs = await MobilePrefsStore.open('${tempDir.path}/prefs.json');
      final store = BetaInviteStore(prefs);
      final text = BetaInviteCopy.shortInvite(BetaInviteVariantId.general);
      expect(ArchiveShareActions.isShareable(text), isTrue);
      await Clipboard.setData(ClipboardData(text: text));
      await store.recordShortCopy(BetaInviteVariantId.general);
      final loaded = await store.load();
      expect(loaded.statsFor(BetaInviteVariantId.general).shortCopiedCount, 1);
      await tempDir.delete(recursive: true);
    });

    test('copy full invite action works', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'beta_invite_copy_',
      );
      final prefs = await MobilePrefsStore.open('${tempDir.path}/prefs.json');
      final store = BetaInviteStore(prefs);
      final text = BetaInviteCopy.fullInvite(BetaInviteVariantId.general);
      expect(ArchiveShareActions.isShareable(text), isTrue);
      expect(text, contains(BetaInviteCopy.privacyReminder));
      await Clipboard.setData(ClipboardData(text: text));
      await store.recordFullCopy(BetaInviteVariantId.general);
      final loaded = await store.load();
      expect(loaded.statsFor(BetaInviteVariantId.general).fullCopiedCount, 1);
      await tempDir.delete(recursive: true);
    });

    test('copy tester task action works', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'beta_invite_copy_',
      );
      final prefs = await MobilePrefsStore.open('${tempDir.path}/prefs.json');
      final store = BetaInviteStore(prefs);
      const text = BetaInviteCopy.testerTask;
      expect(ArchiveShareActions.isShareable(text), isTrue);
      expect(text, contains('After the third, open Archive'));
      await Clipboard.setData(ClipboardData(text: text));
      await store.recordTaskCopy(BetaInviteVariantId.general);
      final loaded = await store.load();
      expect(loaded.statsFor(BetaInviteVariantId.general).taskCopiedCount, 1);
      await tempDir.delete(recursive: true);
    });
  });
}
