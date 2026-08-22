import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/features/privacy/privacy_security_trust_copy.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/settings/privacy_security_trust_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('PrivacySecurityTrustSection', () {
    testWidgets('renders section title and three guarantee blocks', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ListView(
              children: const [
                PrivacySecurityTrustSection(showOnDeviceLink: true),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('privacy_security_trust_section')),
        findsOneWidget,
      );
      expect(find.text(PrivacySecurityTrustCopy.sectionTitle), findsOneWidget);
      expect(
        find.text(PrivacySecurityTrustCopy.encryptedAtRestTitle),
        findsOneWidget,
      );
      expect(
        find.text(PrivacySecurityTrustCopy.onDeviceProcessingTitle),
        findsOneWidget,
      );
      expect(
        find.text(PrivacySecurityTrustCopy.caregiverAccessTitle),
        findsOneWidget,
      );
      expect(
        find.text(PrivacySecurityTrustCopy.encryptedAtRestBody),
        findsOneWidget,
      );
    });

    testWidgets('copy avoids zero-knowledge and superlative claims', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ListView(
              children: const [
                PrivacySecurityTrustSection(showOnDeviceLink: true),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      final text = tester
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data ?? '')
          .join('\n')
          .toLowerCase();

      expect(text, isNot(contains('zero-knowledge')));
      expect(text, isNot(contains('zero knowledge')));
      expect(text, isNot(contains('military-grade')));
      expect(text, isNot(contains('military grade')));
      expect(text, isNot(contains('100% secure')));
    });
  });

  group('PrivacySecurityTrustSection links', () {
    Future<void> pumpWithRouter(
      WidgetTester tester, {
      VoidCallback? onScrollToOnDeviceToggle,
    }) async {
      final onDeviceTargetKey = GlobalKey();
      final router = GoRouter(
        initialLocation: '/settings',
        routes: [
          GoRoute(
            path: '/settings',
            builder: (context, state) => Scaffold(
              body: ListView(
                children: [
                  PrivacySecurityTrustSection(
                    showOnDeviceLink: V1CapabilityRegistry.localAiPrivacyControls,
                    onScrollToOnDeviceToggle: onScrollToOnDeviceToggle ??
                        () {
                          final ctx = onDeviceTargetKey.currentContext;
                          if (ctx != null) {
                            Scrollable.ensureVisible(ctx);
                          }
                        },
                  ),
                  if (V1CapabilityRegistry.localAiPrivacyControls)
                    KeyedSubtree(
                      key: const Key('settings_on_device_processing_toggle'),
                      child: SizedBox(
                        key: onDeviceTargetKey,
                        height: 48,
                        child: const Text('On-device toggle'),
                      ),
                    ),
                  ...List.generate(
                    20,
                    (index) => SizedBox(height: 120, child: Text('filler $index')),
                  ),
                ],
              ),
            ),
          ),
          GoRoute(
            path: '/security',
            builder: (context, state) => const Scaffold(
              key: Key('security_settings_screen'),
              body: Text('Security'),
            ),
          ),
          GoRoute(
            path: '/privacy-security',
            builder: (context, state) => const Scaffold(
              key: Key('privacy_security_control_center_screen'),
              body: Text('Privacy security'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      );
      await tester.pump();
    }

    testWidgets('security link navigates to security settings', (
      tester,
    ) async {
      await pumpWithRouter(tester);

      await tester.tap(find.byKey(const Key('privacy_security_trust_link_security')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('security_settings_screen')), findsOneWidget);
    });

    testWidgets('caregiver link navigates to privacy security control center', (
      tester,
    ) async {
      await pumpWithRouter(tester);

      await tester.tap(
        find.byKey(const Key('privacy_security_trust_link_caregiver')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('privacy_security_control_center_screen')),
        findsOneWidget,
      );
      expect(
        find.text(PrivacySecurityTrustCopy.linkCaregiverAccess),
        findsNothing,
      );
    });

    testWidgets('on-device link scrolls to the never-send toggle', (
      tester,
    ) async {
      if (!V1CapabilityRegistry.localAiPrivacyControls) return;

      await pumpWithRouter(tester);

      final toggle = find.byKey(const Key('settings_on_device_processing_toggle'));
      expect(toggle, findsOneWidget);

      await tester.tap(find.byKey(const Key('privacy_security_trust_link_on_device')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(toggle);
      expect(toggle, findsOneWidget);
    });
  });
}
