import 'package:archiveme_mobile/core/user/user_preferences.dart';
import 'package:archiveme_mobile/features/insights/explore_patterns_screen.dart';
import 'package:archiveme_mobile/features/settings/services/consent_manager.dart';
import 'package:archiveme_mobile/features/settings/views/settings_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    UserPreferences.debugCloudSyncOverride = null;
  });

  testWidgets('Cloud AI Processing subtitle does not claim an encrypted backup', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CloudAiProcessingToggle(value: false, onChanged: (_) {}),
        ),
      ),
    );

    expect(find.text(CloudAiProcessingToggle.title), findsOneWidget);
    expect(find.text(CloudAiProcessingToggle.subtitle), findsOneWidget);
    expect(find.textContaining('encrypts a backup'), findsNothing);
  });

  testWidgets('cancelling Cloud AI consent keeps the settings toggle off', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: _SettingsConsentHost()));

    await tester.tap(find.byKey(const Key('settings_cloud_sync')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cloud_consent_modal')), findsOneWidget);
    await tester.tap(find.byKey(const Key('cloud_consent_keep_local')));
    await tester.pumpAndSettle();

    final toggle = tester.widget<SwitchListTile>(
      find.byKey(const Key('settings_cloud_sync')),
    );
    expect(toggle.value, isFalse);
  });

  testWidgets('dismissing Cloud AI consent keeps the settings toggle off', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: _SettingsConsentHost()));

    await tester.tap(find.byKey(const Key('settings_cloud_sync')));
    await tester.pumpAndSettle();
    Navigator.of(
      tester.element(find.byKey(const Key('cloud_consent_modal'))),
    ).pop();
    await tester.pumpAndSettle();

    final toggle = tester.widget<SwitchListTile>(
      find.byKey(const Key('settings_cloud_sync')),
    );
    expect(toggle.value, isFalse);
  });

  testWidgets('Explore Patterns Opt in uses the same Cloud AI consent modal', (
    tester,
  ) async {
    UserPreferences.debugCloudSyncOverride = false;
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ExplorePatternsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pattern_exploration_cloud_opt_in')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cloud_consent_modal')), findsOneWidget);
    await tester.tap(find.byKey(const Key('cloud_consent_keep_local')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('pattern_exploration_cloud_opt_in')),
      findsOneWidget,
    );
  });
}

class _SettingsConsentHost extends StatefulWidget {
  const _SettingsConsentHost();

  @override
  State<_SettingsConsentHost> createState() => _SettingsConsentHostState();
}

class _SettingsConsentHostState extends State<_SettingsConsentHost> {
  var _enabled = false;

  Future<void> _onChanged(bool enabled) async {
    if (!enabled) {
      setState(() => _enabled = false);
      return;
    }
    final allowed = await const ConsentManager().requestCloudAiConsent(
      context,
    );
    if (!mounted) return;
    setState(() => _enabled = allowed);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CloudAiProcessingToggle(value: _enabled, onChanged: _onChanged),
    );
  }
}
