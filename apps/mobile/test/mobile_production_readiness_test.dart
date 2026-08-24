import 'dart:io';

import 'package:archiveme_mobile/config/app_config.dart';
import 'package:archiveme_mobile/config/developer_settings_gate.dart';
import 'package:archiveme_mobile/config/release_config.dart';
import 'package:archiveme_mobile/config/screenshot_mode.dart';
import 'package:archiveme_mobile/features/activation/archive_evidence_map.dart';
import 'package:archiveme_mobile/features/activation/archive_health_action_plan.dart';
import 'package:archiveme_mobile/features/activation/archive_health_score.dart';
import 'package:archiveme_mobile/features/activation/archive_home_summary.dart';
import 'package:archiveme_mobile/features/activation/archive_insight_feedback.dart';
import 'package:archiveme_mobile/features/activation/archive_workspace_hint_store.dart';
import 'package:archiveme_mobile/features/activation/archive_workspace_hints.dart';
import 'package:archiveme_mobile/features/activation/archive_workspace_layout.dart';
import 'package:archiveme_mobile/features/activation/archive_workspace_quick_actions.dart';
import 'package:archiveme_mobile/features/activation/belief_history_timeline.dart';
import 'package:archiveme_mobile/features/activation/capture_context_tags.dart';
import 'package:archiveme_mobile/features/activation/context_insights.dart';
import 'package:archiveme_mobile/features/activation/evidence_attention_filters.dart';
import 'package:archiveme_mobile/features/activation/insight_quality_dashboard.dart';
import 'package:archiveme_mobile/features/activation/weekly_archive_review.dart';
import 'package:archiveme_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:archiveme_mobile/features/pressure_retention/shareable_archive_proof_engine.dart';
import 'package:archiveme_mobile/features/share/archive_share_text.dart';
import 'package:archiveme_mobile/features/trust/privacy_screen_copy.dart';
import 'package:archiveme_mobile/features/trust/terms_screen_copy.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/security/sensitive_screen_guard.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_storage_sandbox.dart';

JournalEntry _voiceEntry({
  required String id,
  required String transcript,
  DateTime? createdAt,
  String? captureContextTag,
}) => JournalEntry(
  id: id,
  createdAt: createdAt ?? DateTime(2026, 6, 12, 12),
  transcript: transcript,
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
  captureContextTag: captureContextTag,
);

List<JournalEntry> _entries(int count) => List.generate(
  count,
  (i) => _voiceEntry(
    id: 'e$i',
    transcript:
        'I felt pressure at work before saying yes again even when I was tired moment $i.',
    createdAt: DateTime(2026, 6, 9 + i, 12),
    captureContextTag: i.isEven
        ? CaptureContextTagIds.work
        : CaptureContextTagIds.home,
  ),
);

const _bannedLaunchCopy = [
  'diagnosis',
  'symptom',
  'therapy',
  'mental health',
  'streak',
  'guilt',
  'you always',
  'pattern found',
  'certain',
  'must come back',
  'share to unlock',
];

void _expectNoBannedCopy(Iterable<String> visible) {
  for (final text in visible) {
    final lower = text.toLowerCase();
    for (final word in _bannedLaunchCopy) {
      expect(
        lower,
        isNot(contains(word)),
        reason: 'must not contain "$word" in "$text"',
      );
    }
  }
}

void _expectNoVoiceMemoryBranding(Iterable<String> visible) {
  for (final text in visible) {
    expect(text, isNot(contains('VoiceMemory')));
    expect(text.toLowerCase(), isNot(contains('voice memory')));
  }
}

void main() {
  late TestStorageSandbox sandbox;
  setUp(() async {
    sandbox = TestStorageSandbox.create();
    DeveloperSettingsGate.resetForTest();
    DeveloperSettingsGate.suppressDebugBuildForTests = true;
    await ArchiveInsightFeedbackStore.resetForTest();
    ArchiveWorkspaceHintStore.resetForTest();
    await AppServices.resetForTest(
      journalPath: sandbox.journalPath,
      prefsPath: sandbox.prefsPath,
      skipRevenueCat: true,
    );
  });

  tearDown(() => sandbox.dispose());
  tearDown(() {
    DeveloperSettingsGate.suppressDebugBuildForTests = false;
  });

  group('App identity and launch surfaces', () {
    test('app display name remains ArchiveMe', () {
      expect(AppConfig.appName, 'ArchiveMe');

      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(plist, contains('<key>CFBundleDisplayName</key>'));
      expect(plist, contains('<string>ArchiveMe</string>'));
    });

    test('bundle identifier is aligned across Flutter and iOS', () {
      expect(AppConfig.bundleId, 'com.voicememory.mobile');

      final pbxproj = File(
        'ios/Runner.xcodeproj/project.pbxproj',
      ).readAsStringSync();
      expect(
        pbxproj,
        contains('PRODUCT_BUNDLE_IDENTIFIER = com.voicememory.mobile;'),
      );
      expect(
        pbxproj,
        contains(
          'PRODUCT_BUNDLE_IDENTIFIER = com.voicememory.mobile.RunnerTests;',
        ),
      );
    });

    test('screenshot and debug capture modes stay off in release config', () {
      expect(ScreenshotMode.enabled, isFalse);
      expect(ReleaseConfig.screenshotCaptureActive, isFalse);
    });

    test('developer diagnostics stay hidden until gate unlocks', () {
      expect(DeveloperSettingsGate.canShowDeveloperSettings, isFalse);

      final settings = File(
        'lib/features/settings/screens/settings_screen.dart',
      ).readAsStringSync();
      expect(settings, contains('canShowDeveloperSettings'));
      expect(
        settings.indexOf('Developer diagnostics'),
        greaterThan(settings.indexOf('canShowDeveloperSettings')),
      );
      expect(settings, isNot(contains('API base URL')));
      expect(settings, isNot(contains('Backend health')));
      expect(settings, isNot(contains('revenuecat-verify')));
    });
  });

  group('Legal, privacy, and support copy', () {
    test('privacy and terms surfaces use ArchiveMe product voice', () {
      _expectNoVoiceMemoryBranding(PrivacyScreenCopy.all);
      _expectNoVoiceMemoryBranding(TermsScreenCopy.all);
      expect(PrivacyScreenCopy.intro, contains('ArchiveMe'));
    });

    test('support URL references remain ArchiveMe-facing', () {
      expect(AppConfig.privacyUrl, contains('archiveme'));
      expect(AppConfig.privacyUrl, startsWith('https://'));
      expect(AppConfig.supportUrl, contains('archiveme-support'));
      expect(AppConfig.supportUrl, startsWith('https://'));
    });

    test('settings and workspace copy avoid debug-only language', () {
      _expectNoVoiceMemoryBranding([
        VisibleArchiveProofCopy.archiveWorkspaceHintIntroTitle,
        VisibleArchiveProofCopy.archiveWorkspaceHintIntroBody,
        VisibleArchiveProofCopy.insightQualitySettingsTitle,
        VisibleArchiveProofCopy.insightQualitySettingsSubtitle,
        VisibleArchiveProofCopy.shareProofProductLine,
      ]);
      _expectNoBannedCopy([
        VisibleArchiveProofCopy.archiveWorkspaceHintIntroBody,
        VisibleArchiveProofCopy.shareProofVariantA,
        VisibleArchiveProofCopy.shareProofVariantB,
        VisibleArchiveProofCopy.shareProofVariantC,
      ]);
    });
  });

  group('Share-safe privacy', () {
    test(
      'share-safe proof excludes transcripts, tags, map/filter state, and notes',
      () async {
        const engine = ShareableArchiveProofEngine();
        const sensitive =
            'Maria told me about the divorce paperwork at the hospital again';
        ArchiveInsightFeedbackStore.saveCorrectionNote(
          'beliefEvidence',
          'This felt more about hurry than pressure.',
        );
        await ArchiveInsightFeedbackStore.flushForTest();

        final entries = List.generate(
          5,
          (i) => _voiceEntry(
            id: 'e$i',
            transcript: sensitive,
            createdAt: DateTime(2026, 6, 9 + i, 12),
            captureContextTag: CaptureContextTagIds.work,
          ),
        );
        final proof = engine.buildFromJournal(entries: entries);
        final shareText = proof.shareText.toLowerCase();

        expect(proof.hasProof, isTrue);
        expect(shareText, contains('archiveme'));
        expect(shareText, isNot(contains('voicememory')));
        expect(shareText, isNot(contains('maria')));
        expect(shareText, isNot(contains('divorce')));
        expect(shareText, isNot(contains('hospital')));
        expect(shareText, isNot(contains('work')));
        expect(shareText, isNot(contains('untagged')));
        expect(shareText, isNot(contains('filter')));
        expect(shareText, isNot(contains('map')));
        expect(shareText, isNot(contains('hurry')));
        expect(shareText, contains('no private entries shared.'));
        expect(
          ArchiveShareText.includesBannedConsumerCopy(proof.shareText),
          isFalse,
        );
      },
    );
  });

  group('Sensitive routes and navigation safety', () {
    test('insight quality and evidence map drilldowns stay sensitive', () {
      expect(SensitiveRoutes.isSensitiveRoute('/insight-quality'), isTrue);
      expect(
        SensitiveRoutes.isSensitiveRoute(
          ArchiveEvidenceMapNavigation.contextPath(CaptureContextTagIds.work),
        ),
        isTrue,
      );
      expect(
        SensitiveRoutes.isSensitiveRoute(
          ArchiveEvidenceMapNavigation.contextPath(
            ArchiveEvidenceMapRowIds.untagged,
          ),
        ),
        isTrue,
      );
      expect(SensitiveRoutes.isSensitiveRoute('/about'), isFalse);
    });

    test('insight quality route remains reachable', () {
      expect(InsightQualityNavigation.route, '/insight-quality');
    });
  });

  group('Archive workspace low-entry experience', () {
    test('0/1 entry workspace stays calm', () {
      final zeroQuick = ArchiveWorkspaceQuickActionsEngine.build(
        entries: const [],
        archiveHome: ArchiveHomeSummaryEngine.build(entries: const []),
        workspaceLayout: ArchiveWorkspaceLayoutEngine.build(
          entries: const [],
          archiveHome: ArchiveHomeSummaryEngine.build(entries: const []),
          attentionFilters: EvidenceAttentionFiltersEngine.build(
            entries: const [],
          ),
          actionPlan: ArchiveHealthActionPlanEngine.build(entries: const []),
          archiveHealth: ArchiveHealthScoreEngine.build(entries: const []),
          contextInsights: ContextInsightsEngine.build(entries: const []),
          evidenceMap: ArchiveEvidenceMapEngine.build(entries: const []),
        ),
        evidenceMapVisible: false,
      );
      expect(zeroQuick.showCard, isFalse);

      final oneEntries = _entries(1);
      final oneLayout = ArchiveWorkspaceLayoutEngine.build(
        entries: oneEntries,
        archiveHome: ArchiveHomeSummaryEngine.build(entries: oneEntries),
        attentionFilters: EvidenceAttentionFiltersEngine.build(
          entries: oneEntries,
        ),
        actionPlan: ArchiveHealthActionPlanEngine.build(entries: oneEntries),
        archiveHealth: ArchiveHealthScoreEngine.build(entries: oneEntries),
        contextInsights: ContextInsightsEngine.build(entries: oneEntries),
        evidenceMap: ArchiveEvidenceMapEngine.build(entries: oneEntries),
      );
      final oneHints = ArchiveWorkspaceHintsEngine.build(layout: oneLayout);

      expect(oneLayout.evidenceQuality.show, isFalse);
      expect(oneLayout.reviewHistory.show, isFalse);
      expect(oneHints.needsAttentionHint, isNull);
    });

    test('2/3/5 entry gating remains correct', () {
      final two = ArchiveWorkspaceLayoutEngine.build(
        entries: _entries(2),
        archiveHome: ArchiveHomeSummaryEngine.build(entries: _entries(2)),
        attentionFilters: EvidenceAttentionFiltersEngine.build(
          entries: _entries(2),
        ),
        actionPlan: ArchiveHealthActionPlanEngine.build(entries: _entries(2)),
        archiveHealth: ArchiveHealthScoreEngine.build(entries: _entries(2)),
        contextInsights: ContextInsightsEngine.build(entries: _entries(2)),
        evidenceMap: ArchiveEvidenceMapEngine.build(entries: _entries(2)),
      );
      expect(two.reviewHistory.show, isFalse);

      final three = ArchiveWorkspaceLayoutEngine.build(
        entries: _entries(3),
        archiveHome: ArchiveHomeSummaryEngine.build(entries: _entries(3)),
        attentionFilters: EvidenceAttentionFiltersEngine.build(
          entries: _entries(3),
        ),
        actionPlan: ArchiveHealthActionPlanEngine.build(entries: _entries(3)),
        archiveHealth: ArchiveHealthScoreEngine.build(entries: _entries(3)),
        contextInsights: ContextInsightsEngine.build(entries: _entries(3)),
        evidenceMap: ArchiveEvidenceMapEngine.build(entries: _entries(3)),
      );
      expect(three.evidenceQuality.show, isTrue);
      expect(three.reviewHistory.show, isFalse);

      final five = ArchiveWorkspaceLayoutEngine.build(
        entries: _entries(5),
        archiveHome: ArchiveHomeSummaryEngine.build(entries: _entries(5)),
        attentionFilters: EvidenceAttentionFiltersEngine.build(
          entries: _entries(5),
        ),
        actionPlan: ArchiveHealthActionPlanEngine.build(entries: _entries(5)),
        archiveHealth: ArchiveHealthScoreEngine.build(entries: _entries(5)),
        contextInsights: ContextInsightsEngine.build(entries: _entries(5)),
        evidenceMap: ArchiveEvidenceMapEngine.build(entries: _entries(5)),
        beliefHistory: BeliefHistoryTimelineEngine.build(entries: _entries(5)),
        weeklyReview: WeeklyArchiveReviewEngine.build(entries: _entries(5)),
      );
      expect(five.reviewHistory.show, isTrue);
    });
  });

  group('Persistence and evidence integrity', () {
    test('manual context tag editing still persists', () async {
      final dir = Directory.systemTemp.createTempSync('archiveme_readiness_');
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });

      final store = await JournalStore.open(
        '${dir.path}/entries.json',
        encryptAtRest: false,
      );
      await store.save(
        _voiceEntry(
          id: 'e1',
          transcript:
              'I felt pressure at work before saying yes again even when I was tired.',
        ),
      );
      await store.updateCaptureContextTag(
        'e1',
        tagId: CaptureContextTagIds.decision,
      );

      final reloaded = await JournalStore.open(
        '${dir.path}/entries.json',
        encryptAtRest: false,
      );
      final loaded = await reloaded.getById('e1');
      expect(loaded?.captureContextTag, CaptureContextTagIds.decision);
    });

    test('hint dismissal persists locally', () async {
      ArchiveWorkspaceHintStore.dismiss(ArchiveWorkspaceHintIds.intro);
      await ArchiveWorkspaceHintStore.flushForTest();
      ArchiveWorkspaceHintStore.resetForTest();
      await ArchiveWorkspaceHintStore.ensureLoaded();

      expect(
        ArchiveWorkspaceHintStore.isDismissed(ArchiveWorkspaceHintIds.intro),
        isTrue,
      );
    });
  });
}