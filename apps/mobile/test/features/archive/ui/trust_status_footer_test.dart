import 'package:archiveme_mobile/features/archive/ui/trust_status_footer.dart';
import 'package:archiveme_mobile/features/archive/ui/trust_status_footer_copy.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Claims the processing chip must not make while no model binary ships.
///
/// `find -L apps/mobile -name '*.onnx' -o -name '*.gguf' -o -name '*.tflite'`
/// returns nothing and `pubspec.yaml` declares one asset
/// (`config/backend_url.txt`), so every encoder resolves to a deterministic
/// stand-in. Copy that says a language model runs here is false for the shipped
/// build, and this list is what "false" looked like before the fix.
const _localModelExecutionClaims = [
  'local language models run on this device',
  'language model',
  'models run on this device',
];

void main() {
  group('TrustStatusFooter', () {
    testWidgets('defaults to the storage claim, not a processing claim', (
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
      expect(find.text(TrustStatusFooterCopy.encryptedAtRest), findsOneWidget);
      expect(find.text(TrustStatusFooterCopy.storedOnDevice), findsOneWidget);
      expect(find.text(TrustStatusFooterCopy.processedOnDevice), findsNothing);
    });

    testWidgets('renders the processing chip only when an entry recorded one', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: TrustStatusFooter(processingUsedOnDevice: true),
          ),
        ),
      );

      expect(
        find.text(TrustStatusFooterCopy.processedOnDevice),
        findsOneWidget,
      );
      expect(find.text(TrustStatusFooterCopy.storedOnDevice), findsNothing);
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

  group('TrustStatusFooterCopy', () {
    test('no variant claims a language model runs on this device', () {
      for (final copy in const [
        TrustStatusFooterCopy.processedOnDevice,
        TrustStatusFooterCopy.storedOnDevice,
        TrustStatusFooterCopy.onDeviceSemanticLabel,
        TrustStatusFooterCopy.storedOnDeviceSemanticLabel,
      ]) {
        final lower = copy.toLowerCase();
        for (final claim in _localModelExecutionClaims) {
          expect(lower, isNot(contains(claim)), reason: copy);
        }
      }
    });

    test(
      'the default variant scopes the local claim to storage and search',
      () {
        final lower = TrustStatusFooterCopy.storedOnDeviceSemanticLabel
            .toLowerCase();
        expect(lower, contains('stored and searched on this device'));
        expect(lower, contains('on our servers when you allow that'));
      },
    );

    test('the selector follows the flag rather than a constant', () {
      expect(TrustStatusFooterCopy.storedOnDevice, 'Stored on this phone');
      expect(
        TrustStatusFooterCopy.processedOnDevice,
        'Processed here — not sent',
      );
      expect(
        TrustStatusFooterCopy.labelFor(processingUsedOnDevice: false),
        TrustStatusFooterCopy.storedOnDevice,
      );
      expect(
        TrustStatusFooterCopy.labelFor(processingUsedOnDevice: true),
        TrustStatusFooterCopy.processedOnDevice,
      );
      expect(
        TrustStatusFooterCopy.semanticLabelFor(processingUsedOnDevice: false),
        TrustStatusFooterCopy.storedOnDeviceSemanticLabel,
      );
      expect(
        TrustStatusFooterCopy.semanticLabelFor(processingUsedOnDevice: true),
        TrustStatusFooterCopy.onDeviceSemanticLabel,
      );
    });
  });
}
