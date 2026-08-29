import 'package:archiveme_mobile/features/settings/presentation/caregiver_consent_copy.dart';
import 'package:archiveme_mobile/features/settings/presentation/caregiver_consent_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders AppBar title, trust banner, and master toggle', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text(CaregiverConsentCopy.screenTitle), findsOneWidget);
    expect(find.byType(Card), findsOneWidget);
    expect(find.text(CaregiverConsentCopy.banner), findsOneWidget);
    expect(find.text(CaregiverConsentCopy.masterTitle), findsOneWidget);
    expect(find.text(CaregiverConsentCopy.previewConnectedStatus), findsOneWidget);
    expect(find.text(CaregiverConsentCopy.revokeCta), findsOneWidget);
    expect(_tile(tester, CaregiverConsentScreen.masterSwitchKey).value, isTrue);
  });

  testWidgets('disabling master makes granular switches inactive', (
    tester,
  ) async {
    await _pump(tester);

    expect(_tile(tester, CaregiverConsentScreen.moodRowKey).onChanged, isNotNull);
    expect(
      _tile(tester, CaregiverConsentScreen.alertsRowKey).onChanged,
      isNotNull,
    );
    expect(
      _tile(tester, CaregiverConsentScreen.checkInsRowKey).onChanged,
      isNotNull,
    );

    await tester.tap(find.text(CaregiverConsentCopy.masterTitle));
    await tester.pumpAndSettle();

    expect(_tile(tester, CaregiverConsentScreen.masterSwitchKey).value, isFalse);
    expect(_tile(tester, CaregiverConsentScreen.moodRowKey).onChanged, isNull);
    expect(_tile(tester, CaregiverConsentScreen.alertsRowKey).onChanged, isNull);
    expect(
      _tile(tester, CaregiverConsentScreen.checkInsRowKey).onChanged,
      isNull,
    );

    final moodBefore = _tile(tester, CaregiverConsentScreen.moodRowKey).value;
    await tester.tap(find.text(CaregiverConsentCopy.moodTitle));
    await tester.pumpAndSettle();
    expect(_tile(tester, CaregiverConsentScreen.moodRowKey).value, moodBefore);
  });

  testWidgets('revoke flow zeros all sharing switches', (tester) async {
    await _pump(tester);

    await tester.ensureVisible(find.text(CaregiverConsentCopy.revokeCta));
    await tester.tap(find.text(CaregiverConsentCopy.revokeCta));
    await tester.pumpAndSettle();

    expect(find.text(CaregiverConsentCopy.revokeConfirmTitle), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, CaregiverConsentCopy.revokeConfirmAction));
    await tester.pumpAndSettle();

    expect(find.text(CaregiverConsentCopy.revokeConfirmTitle), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    expect(_tile(tester, CaregiverConsentScreen.masterSwitchKey).value, isFalse);
    expect(_tile(tester, CaregiverConsentScreen.moodRowKey).value, isFalse);
    expect(_tile(tester, CaregiverConsentScreen.alertsRowKey).value, isFalse);
    expect(_tile(tester, CaregiverConsentScreen.checkInsRowKey).value, isFalse);
    expect(_tile(tester, CaregiverConsentScreen.moodRowKey).onChanged, isNull);
    expect(_tile(tester, CaregiverConsentScreen.alertsRowKey).onChanged, isNull);
    expect(
      _tile(tester, CaregiverConsentScreen.checkInsRowKey).onChanged,
      isNull,
    );
  });

  testWidgets('trust banner does not claim 100% private', (tester) async {
    await _pump(tester);

    expect(find.text(CaregiverConsentCopy.banner), findsOneWidget);
    expect(find.textContaining('100% private'), findsNothing);
    expect(
      CaregiverConsentCopy.banner.toLowerCase(),
      isNot(contains('100% private')),
    );
  });
}

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    const MaterialApp(home: CaregiverConsentScreen()),
  );
  await tester.pumpAndSettle();
}

SwitchListTile _tile(WidgetTester tester, Key key) {
  return tester.widget<SwitchListTile>(find.byKey(key));
}
