import 'package:archiveme_mobile/features/onboarding/ui/on_device_hero_screen.dart';
import 'package:archiveme_mobile/features/onboarding/ui/remote_processing_consent_step.dart';
import 'package:archiveme_mobile/features/sync/application/background_sync_state.dart';
import 'package:archiveme_mobile/features/sync/application/sync_status_provider.dart';
import 'package:archiveme_mobile/features/sync/presentation/sync_status_snapshot.dart';
import 'package:archiveme_mobile/screens/onboarding_screen.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/account/privacy_trust_centre_screen.dart';
import 'package:archiveme_mobile/widgets/privacy/privacy_summary_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/rendered_sentence_duplication.dart';

/// Gate 1 — a claim is stated once per screen, as rendered.
///
/// The other two duplication gates read source. This one reads the widget
/// tree, and it is the only one that catches what happened on `/privacy`:
/// `TrustBadge` and `PrivacyScreenCopy.privateByDefaultBody` both carried
/// "Nothing is sent unless you choose a feature that needs it", but each
/// embedded it in a different paragraph, so no two constants were equal and no
/// source-level check saw anything.
///
/// `/privacy-security` and `/settings` belong to other work in flight and are
/// not covered here yet. They are the obvious next two.
void main() {
  Widget withProviders(Widget child) => ProviderScope(
    overrides: [
      syncStatusProvider.overrideWithValue(
        const SyncStatusSnapshot(sync: BackgroundSyncState(), isOnline: true),
      ),
    ],
    child: child,
  );

  Future<void> pumpFrames(WidgetTester tester, {int frames = 5}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('/privacy-trust-centre states each claim once', (tester) async {
    // `/privacy` redirects here now, and its disclosure came with it. That
    // made this the screen with the most claims on one scroll, which is
    // exactly where a second wording of an existing claim would land.
    await tester.binding.setSurfaceSize(const Size(800, 6000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      withProviders(
        MaterialApp(
          theme: AppTheme.light(),
          home: const PrivacyTrustCentreScreen(),
        ),
      ),
    );
    await pumpFrames(tester);

    expectNoDuplicatedSentences(tester, screen: '/privacy-trust-centre');
  });

  testWidgets('the migrated privacy disclosure states each claim once', (
    tester,
  ) async {
    await tester.pumpWidget(
      withProviders(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: SingleChildScrollView(child: PrivacySummarySection()),
          ),
        ),
      ),
    );
    await tester.pump();

    expectNoDuplicatedSentences(tester, screen: 'privacy disclosure');
  });

  testWidgets('the onboarding welcome page states each claim once', (
    tester,
  ) async {
    await tester.pumpWidget(
      withProviders(
        const MaterialApp(home: OnboardingScreen(debugStartAtWelcome: true)),
      ),
    );
    await pumpFrames(tester);

    expectNoDuplicatedSentences(tester, screen: 'onboarding welcome');
  });

  testWidgets('the remote processing consent step states each claim once', (
    tester,
  ) async {
    await tester.pumpWidget(
      withProviders(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: RemoteProcessingConsentStep(onDecision: (_) {}),
          ),
        ),
      ),
    );
    await pumpFrames(tester);

    expectNoDuplicatedSentences(tester, screen: 'remote processing consent');
  });

  testWidgets('the on-device hero states each claim once', (tester) async {
    await tester.pumpWidget(
      withProviders(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: OnDeviceHeroScreen(onContinue: () {}, onSeeDetails: () {}),
          ),
        ),
      ),
    );
    await pumpFrames(tester);

    expectNoDuplicatedSentences(tester, screen: 'on-device hero');
  });

  group('the helper itself', () {
    testWidgets('catches a sentence embedded in two different paragraphs', (
      tester,
    ) async {
      // Neither string equals the other, which is exactly why the constant
      // level gate cannot see this.
      const shared =
          'Nothing is sent unless you choose a feature that needs it.';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Text('$shared Choose transcription and it goes to a server.'),
                Text('$shared Your moments stay in local databases.'),
              ],
            ),
          ),
        ),
      );

      final duplicates = duplicatedRenderedSentences(tester);
      expect(duplicates, hasLength(1));
      expect(duplicates.values.single, hasLength(2));
    });

    testWidgets('short labels may repeat', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [Text('Privacy & Security'), Text('Privacy & Security')],
            ),
          ),
        ),
      );

      expect(duplicatedRenderedSentences(tester), isEmpty);
    });

    test('sentence splitting keeps em-dash halves apart', () {
      expect(
        splitIntoSentences('Local counters only — nothing is uploaded.'),
        ['Local counters only', 'nothing is uploaded'],
      );
    });

    test('normalisation ignores case and punctuation', () {
      expect(
        normaliseSentence('  Protects them, INSTEAD of asserting it here!  '),
        'protects them instead of asserting it here',
      );
    });
  });
}
