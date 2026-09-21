import 'dart:io';

import 'package:archiveme_mobile/billing/archive_entitlement_reader.dart';
import 'package:archiveme_mobile/dev/visual_audit_overrides.dart';
import 'package:archiveme_mobile/l10n/generated/app_localizations.dart';
import 'package:archiveme_mobile/screens/record_screen.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/app_provider_scope.dart';
import 'support/app_services_test_lifecycle.dart';

const _smallScreen = Size(360, 640);

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('record_overflow_test_');
    await AppServices.resetForTest(
      journalPath: '${tempDir.path}/journal.json',
      prefsPath: '${tempDir.path}/prefs.json',
      skipRevenueCat: true,
    );
    VisualAuditOverrides.setRecordPresentation(
      const RecordAuditPresentation(ui: RecordUiState.ready),
    );
  });

  tearDown(() async {
    await settleAppServicesForTest();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    VisualAuditOverrides.setRecordPresentation(null);
  });

  Future<void> pumpRecordScreen(
    WidgetTester tester, {
    RecordUiState ui = RecordUiState.ready,
  }) async {
    VisualAuditOverrides.setRecordPresentation(RecordAuditPresentation(ui: ui));
    await tester.binding.setSurfaceSize(_smallScreen);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      withAppProviderScope(
        MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: RecordScreen(
              entitlementReader: FakeArchiveEntitlementReader(pro: false),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> scrollRecordScreen(WidgetTester tester) async {
    final scroll = find.byKey(const Key('record_screen_scroll'));
    expect(scroll, findsOneWidget);
    await tester.drag(scroll, const Offset(0, -500));
    await tester.pumpAndSettle();
  }

  group('Record screen accessibility', () {
    Future<void> pumpAtTextScale(
      WidgetTester tester, {
      required double scale,
      RecordUiState ui = RecordUiState.ready,
    }) async {
      VisualAuditOverrides.setRecordPresentation(
        RecordAuditPresentation(ui: ui),
      );
      await tester.binding.setSurfaceSize(_smallScreen);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        withAppProviderScope(
          MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: RecordScreen(
                entitlementReader: FakeArchiveEntitlementReader(pro: false),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets(
      'ready state remains usable at 200% text scale with no overflow',
      (tester) async {
        await pumpAtTextScale(tester, scale: 2);
        expect(tester.takeException(), isNull);

        await scrollRecordScreen(tester);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'recording state remains usable at 200% text scale with no overflow',
      (tester) async {
        await pumpAtTextScale(tester, scale: 2, ui: RecordUiState.recording);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'record button exposes an accessible label from its visible text, '
      'not a bare icon-only control',
      (tester) async {
        final handle = tester.ensureSemantics();
        await pumpRecordScreen(tester);
        final button = find.byKey(const Key('capture_entry_record_cta'));
        expect(button, findsOneWidget);
        expect(
          find.descendant(
            of: button,
            matching: find.bySemanticsLabel(RegExp('.+')),
          ),
          findsWidgets,
          reason:
              'the mic-icon record CTA must carry a real accessible label, '
              'not just a decorative icon',
        );
        handle.dispose();
      },
    );
  });
}
