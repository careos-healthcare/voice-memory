import 'package:archiveme_mobile/features/archive/ui/trust_status_footer.dart';
import 'package:archiveme_mobile/features/archive/ui/trust_status_footer_copy.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TrustStatusFooter', () {
    testWidgets('renders muted encrypted and on-device indicators', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: TrustStatusFooter()),
        ),
      );

      expect(find.byKey(TrustStatusFooter.footerKey), findsOneWidget);
      expect(find.byKey(TrustStatusFooter.encryptedKey), findsOneWidget);
      expect(find.byKey(TrustStatusFooter.onDeviceKey), findsOneWidget);
      expect(
        find.text(TrustStatusFooterCopy.encryptedAtRest),
        findsOneWidget,
      );
      expect(
        find.text(TrustStatusFooterCopy.processedOnDevice),
        findsOneWidget,
      );
    });

    testWidgets('uses lock and memory icons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: TrustStatusFooter()),
        ),
      );

      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.byIcon(Icons.memory_outlined), findsOneWidget);
    });
  });
}
