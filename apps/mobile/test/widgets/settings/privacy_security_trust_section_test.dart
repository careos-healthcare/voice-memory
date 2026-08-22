import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_feature_flags.dart';
import 'package:archiveme_mobile/features/privacy/privacy_security_trust_copy.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/settings/privacy_security_trust_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  // The caregiver guarantee and link are gated on the capability flag, which is
  // off in a shipped build. These cases cover the section as it looks once the
  // gate opens; `caregiver_access_nav_gate_test.dart` covers the closed state.
  setUp(() {
    CaregiverFeatureFlags.debugOverride = true;
  });

  tearDown(() {
    CaregiverFeatureFlags.debugOverride = null;
  });

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
    // The stub route puts 20 filler tiles after the section, so on the default
    // 800x600 surface the links and the on-device target sit outside the lazy
    // ListView's build extent and no finder can reach them. Widening the
    // surface keeps these cases about navigation rather than about scrolling.
    Future<void> pumpWithRouter(
      WidgetTester tester, {
      VoidCallback? onScrollToOnDeviceToggle,
    }) async {
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

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
            path: '/caregiver-access',
            builder: (context, state) => const Scaffold(
              key: Key('caregiver_access_screen_stub'),
              body: Text('Caregiver access'),
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

    // Previously asserted `/privacy-security` as the destination, which the
    // widget has not pushed since the canonical screen moved to
    // `/caregiver-access`; the case failed on an unregistered route.
    testWidgets('caregiver link navigates to the caregiver access screen', (
      tester,
    ) async {
      await pumpWithRouter(tester);

      await tester.tap(
        find.byKey(const Key('privacy_security_trust_link_caregiver')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('caregiver_access_screen_stub')),
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
