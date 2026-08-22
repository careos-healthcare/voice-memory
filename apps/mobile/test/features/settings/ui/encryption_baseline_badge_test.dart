import 'package:archiveme_mobile/features/settings/ui/encryption_baseline_badge.dart';
import 'package:archiveme_mobile/security/privacy_copy_policy.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.light(),
    home: const Scaffold(body: EncryptionBaselineBadge()),
  ),
);

void main() {
  group('EncryptionBaselineBadge', () {
    testWidgets('renders the scoped label and its supporting detail', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.byKey(EncryptionBaselineBadge.badgeKey), findsOneWidget);
      expect(
        find.text(PrivacyCopyPolicy.encryptedAtRestScoped),
        findsOneWidget,
      );
      expect(
        find.text(PrivacyCopyPolicy.encryptionBaselineDetail),
        findsOneWidget,
      );
    });

    testWidgets('stays quieter than body copy', (tester) async {
      // The brief asked for a footnote, not a headline: smaller than body type,
      // a subtle lock glyph, and a muted colour rather than an accent.
      await _pump(tester);

      final label = tester.widget<Text>(
        find.text(PrivacyCopyPolicy.encryptedAtRestScoped),
      );
      final detail = tester.widget<Text>(
        find.text(PrivacyCopyPolicy.encryptionBaselineDetail),
      );
      final bodyFontSize = AppTheme.light().textTheme.bodyMedium?.fontSize ?? 14;

      expect(label.style?.fontSize, lessThan(bodyFontSize));
      expect(detail.style?.fontSize, lessThan(label.style!.fontSize!));
      expect(detail.style?.color?.a, lessThan(label.style!.color!.a));

      final icon = tester.widget<Icon>(find.byIcon(Icons.lock_outline));
      expect(icon.size, 12);
    });

    testWidgets('exposes one semantic node carrying the full scope', (
      tester,
    ) async {
      await _pump(tester);

      // A screen reader should get the exclusions too, not just the label,
      // since the visible chip alone would read as broader than it is.
      expect(
        find.bySemanticsLabel(
          '${PrivacyCopyPolicy.encryptedAtRestScoped}. '
          '${PrivacyCopyPolicy.encryptionBaselineDetail}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('wraps instead of overflowing at large text scale', (
      tester,
    ) async {
      // Hosted the way `PrivacySecurityScreen` hosts it — inside a scrolling
      // list. At 2x scale this footnote is taller than a phone screen, which is
      // the host's problem to scroll; what must not happen is the label running
      // off the side, which is what an unflexible Row did.
      tester.view.physicalSize = const Size(360 * 3, 640 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: ListView(children: const [EncryptionBaselineBadge()]),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byKey(EncryptionBaselineBadge.badgeKey), findsOneWidget);
    });
  });
}
