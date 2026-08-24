import 'package:archiveme_mobile/config/app_config.dart';
import 'package:archiveme_mobile/features/sync/application/background_sync_state.dart';
import 'package:archiveme_mobile/features/sync/application/sync_status_provider.dart';
import 'package:archiveme_mobile/features/sync/presentation/sync_status_snapshot.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/features/settings/screens/about_screen.dart';
import 'package:archiveme_mobile/features/settings/screens/privacy_screen.dart';
import 'package:archiveme_mobile/features/settings/screens/settings_screen.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  /// `PushedScreenShell` puts a `SyncStatusAppBarAction` in the AppBar, and
  /// that is a `ConsumerWidget`, so all three shells here threw
  /// `Bad state: No ProviderScope found` during `pumpWidget`. The status is
  /// overridden rather than left to resolve so the indicator stays hidden and
  /// contributes no text of its own to the brand assertions below.
  Widget withSyncStatus(Widget child) => ProviderScope(
    overrides: [
      syncStatusProvider.overrideWithValue(
        const SyncStatusSnapshot(sync: BackgroundSyncState(), isOnline: true),
      ),
    ],
    child: child,
  );

  group('Consumer-visible shell headers', () {
    testWidgets('privacy shell app bar avoids VoiceMemory', (tester) async {
      await tester.pumpWidget(
        withSyncStatus(
          MaterialApp(theme: AppTheme.light(), home: const PrivacyScreen()),
        ),
      );
      await tester.pump();
      expect(find.textContaining('VoiceMemory'), findsNothing);
      expect(find.text('Privacy'), findsOneWidget);
    });

    testWidgets('settings shell avoids VoiceMemory in app bar', (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      );
      await tester.pumpWidget(
        withSyncStatus(
          MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
        ),
      );
      await tester.pump();
      expect(find.textContaining('VoiceMemory'), findsNothing);
      expect(find.text(ConsumerUiCopy.settings), findsOneWidget);
    });

    testWidgets('about shell shows ArchiveMe not VoiceMemory', (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (context, state) => const AboutScreen()),
        ],
      );
      await tester.pumpWidget(
        withSyncStatus(
          MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
        ),
      );
      await tester.pump();
      expect(find.textContaining('VoiceMemory'), findsNothing);
      expect(find.textContaining('ArchiveMe'), findsWidgets);
    });

    test('material app title uses ArchiveMe', () {
      expect(AppConfig.appName, 'ArchiveMe');
    });
  });
}