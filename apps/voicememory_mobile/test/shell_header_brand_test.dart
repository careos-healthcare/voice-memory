import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/config/app_config.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/screens/about_screen.dart';
import 'package:voicememory_mobile/screens/privacy_screen.dart';
import 'package:voicememory_mobile/screens/settings_screen.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';

void main() {
  group('Consumer-visible shell headers', () {
    testWidgets('privacy shell app bar avoids VoiceMemory', (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light(), home: const PrivacyScreen()),
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
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
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
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
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
