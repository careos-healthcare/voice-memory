import 'package:archiveme_mobile/features/capture_flow/ui/capture_screen_host.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/app_provider_scope.dart';
import 'support/app_services_test_lifecycle.dart';
import 'support/test_storage_sandbox.dart';

void main() {
  late TestStorageSandbox sandbox;

  setUp(() async {
    sandbox = TestStorageSandbox.create();
    await AppServices.resetForTest(
      journalPath: sandbox.journalPath,
      prefsPath: sandbox.prefsPath,
      skipRevenueCat: true,
    );
  });

  tearDown(() async {
    await settleAppServicesForTest();
    sandbox.dispose();
  });

  Future<void> pumpCaptureReady(
    WidgetTester tester, {
    double textScale = 1.0,
  }) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      withAppProviderScope(
        MaterialApp(
          theme: AppTheme.light(),
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: const Scaffold(body: CaptureScreenHost()),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('CaptureScreen ready layout', () {
    testWidgets('renders without overflow on a small screen', (tester) async {
      await pumpCaptureReady(tester);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('capture_start_voice')), findsOneWidget);
    });

    testWidgets('renders without overflow at 200% text scale', (tester) async {
      await pumpCaptureReady(tester, textScale: 2);
      expect(tester.takeException(), isNull);
      final startVoice = find.byKey(const Key('capture_start_voice'));
      expect(startVoice, findsOneWidget);
      await tester.ensureVisible(startVoice);
      expect(tester.takeException(), isNull);
    });
  });
}
