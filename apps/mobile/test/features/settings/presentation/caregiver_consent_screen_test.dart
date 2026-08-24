import 'package:archiveme_mobile/features/settings/presentation/caregiver_consent_copy.dart';
import 'package:archiveme_mobile/features/settings/presentation/caregiver_consent_screen.dart';
import 'package:archiveme_mobile/features/settings/ui/caregiver_consent_screen.dart'
    as ui_export;
import 'package:archiveme_mobile/security/privacy_copy_policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Default-constructor widget coverage lives in
// test/features/settings/caregiver_consent_screen_test.dart.
void main() {
  test('CaregiverConsentScreen is exported from settings/presentation', () {
    expect(CaregiverConsentScreen.screenKey, const Key('caregiver_consent_screen'));
    expect(identical(CaregiverConsentScreen, ui_export.CaregiverConsentScreen), isTrue);
    expect(CaregiverConsentCopy.settingsTileTitle, 'Caregiver Access & Permissions');
    expect(CaregiverConsentCopy.screenTitle, 'Caregiver Access & Permissions');
    expect(CaregiverConsentCopy.revokeCta, 'Revoke All Caregiver Access');
    expect(CaregiverConsentCopy.statusOff, 'Sharing disabled');
    expect(CaregiverConsentCopy.statusOnAnonymous, 'Sharing enabled');
    expect(CaregiverConsentCopy.sharingPermissions, 'Sharing Permissions');
    expect(
      CaregiverConsentCopy.previewConnectedStatus,
      'Connected to Heather (Primary Caregiver)',
    );
  });

  test('banner stays accurate and omits the 100% / never-leaves sentence', () {
    expect(CaregiverConsentCopy.banner, contains('opening words'));
    expect(CaregiverConsentCopy.banner, contains('Raw audio stays on this phone'));
    expect(CaregiverConsentCopy.banner, contains('unless you choose'));
    expect(CaregiverConsentCopy.banner.toLowerCase(), isNot(contains('100%')));
    expect(
      CaregiverConsentCopy.banner.toLowerCase(),
      isNot(contains('never leaves')),
    );
    expect(
      CaregiverConsentCopy.banner.toLowerCase(),
      isNot(contains('strictly')),
    );
    expect(
      CaregiverConsentCopy.banner.toLowerCase(),
      isNot(contains('summarized trend')),
    );
    expect(
      CaregiverConsentCopy.banner.toLowerCase(),
      isNot(contains('100% private and on this phone')),
    );
  });

  test('Heather is a preview fixture, not default production copy', () {
    expect(CaregiverConsentCopy.statusOff, isNot(contains('Heather')));
    expect(CaregiverConsentCopy.statusOnAnonymous, isNot(contains('Heather')));
    expect(CaregiverConsentCopy.revokeConfirmBody, isNot(contains('Heather')));
    expect(
      CaregiverConsentCopy.revokeConfirmBody.toLowerCase(),
      isNot(contains('stop all data sharing with heather')),
    );
    expect(CaregiverConsentCopy.revokeConfirmBody, contains('stop sharing'));
    expect(CaregiverConsentCopy.revokeConfirmBody, contains('caregiver'));
    expect(
      CaregiverConsentCopy.revokeConfirmBodyFor(previewMode: false),
      CaregiverConsentCopy.revokeConfirmBody,
    );
    expect(
      CaregiverConsentCopy.revokeConfirmBodyFor(previewMode: true),
      contains('Heather'),
    );
    expect(
      CaregiverConsentCopy.connectedStatus(),
      CaregiverConsentCopy.statusOnAnonymous,
    );
    expect(
      CaregiverConsentCopy.connectedStatus(caregiverDisplayName: 'Sam'),
      'Connected to Sam',
    );
    expect(
      CaregiverConsentCopy.connectedStatus(
        caregiverDisplayName: 'Sam',
        caregiverRole: 'Primary Caregiver',
      ),
      'Connected to Sam (Primary Caregiver)',
    );
  });

  test('no shipped line trips PrivacyCopyPolicy', () {
    final offenders = <String, List<String>>{};
    for (final line in [
      CaregiverConsentCopy.settingsTileTitle,
      CaregiverConsentCopy.settingsTileSubtitle,
      CaregiverConsentCopy.screenTitle,
      CaregiverConsentCopy.banner,
      CaregiverConsentCopy.masterTitle,
      CaregiverConsentCopy.statusOff,
      CaregiverConsentCopy.statusOnAnonymous,
      CaregiverConsentCopy.moodTitle,
      CaregiverConsentCopy.moodBody,
      CaregiverConsentCopy.alertsTitle,
      CaregiverConsentCopy.alertsBody,
      CaregiverConsentCopy.checkInsTitle,
      CaregiverConsentCopy.checkInsBody,
      CaregiverConsentCopy.sharingPermissions,
      CaregiverConsentCopy.revokeCta,
      CaregiverConsentCopy.revokeConfirmTitle,
      CaregiverConsentCopy.revokeConfirmBody,
      CaregiverConsentCopy.revokeConfirmBodyPreview,
      CaregiverConsentCopy.revokeCancel,
      CaregiverConsentCopy.revokeConfirmAction,
      CaregiverConsentCopy.connectedStatus(caregiverDisplayName: 'Sam'),
      CaregiverConsentCopy.previewConnectedStatus,
    ]) {
      final violations = PrivacyCopyPolicy.violationsInLiteral(line);
      if (violations.isNotEmpty) offenders[line] = violations;
    }
    expect(offenders, isEmpty);
  });

  testWidgets('isolated pump needs no MultiPartyAccessService', (tester) async {
    await _pumpScreen(tester);

    expect(find.byKey(CaregiverConsentScreen.screenKey), findsOneWidget);
    expect(find.text(CaregiverConsentCopy.screenTitle), findsOneWidget);
    expect(find.byKey(CaregiverConsentScreen.bannerKey), findsOneWidget);
    expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
    expect(find.text(CaregiverConsentCopy.banner), findsOneWidget);
    expect(find.text(CaregiverConsentCopy.masterTitle), findsOneWidget);
    expect(find.text(CaregiverConsentCopy.statusOff), findsOneWidget);
    expect(find.text(CaregiverConsentCopy.sharingPermissions), findsOneWidget);
    expect(find.byKey(CaregiverConsentScreen.revokeKey), findsNothing);
    expect(find.text(CaregiverConsentCopy.revokeCta), findsNothing);
    expect(find.textContaining('Heather'), findsNothing);
    expect(find.textContaining('100%'), findsNothing);
    expect(find.textContaining('never leaves'), findsNothing);
    expect(_tile(tester, CaregiverConsentScreen.masterSwitchKey).value, isFalse);
    expect(_tile(tester, CaregiverConsentScreen.moodRowKey).value, isFalse);
    expect(_tile(tester, CaregiverConsentScreen.alertsRowKey).value, isFalse);
    expect(_tile(tester, CaregiverConsentScreen.checkInsRowKey).value, isFalse);
  });

  testWidgets('revoke is hidden when sharing is off and visible when on', (
    tester,
  ) async {
    await _pumpScreen(tester);

    expect(find.byKey(CaregiverConsentScreen.revokeKey), findsNothing);
    expect(find.byIcon(Icons.person_remove_outlined), findsNothing);

    await tester.tap(find.byKey(CaregiverConsentScreen.masterSwitchKey));
    await tester.pump();

    expect(find.byKey(CaregiverConsentScreen.revokeKey), findsOneWidget);
    expect(find.byIcon(Icons.person_remove_outlined), findsOneWidget);
    expect(find.text(CaregiverConsentCopy.revokeCta), findsOneWidget);
  });

  testWidgets('master on enables granular switches; off disables them', (
    tester,
  ) async {
    await _pumpScreen(tester);

    expect(find.byType(SwitchListTile), findsNWidgets(4));
    expect(_tile(tester, CaregiverConsentScreen.moodRowKey).onChanged, isNull);
    expect(_tile(tester, CaregiverConsentScreen.alertsRowKey).onChanged, isNull);
    expect(
      _tile(tester, CaregiverConsentScreen.checkInsRowKey).onChanged,
      isNull,
    );

    await tester.tap(find.byKey(CaregiverConsentScreen.masterSwitchKey));
    await tester.pump();

    expect(_tile(tester, CaregiverConsentScreen.masterSwitchKey).value, isTrue);
    expect(find.text(CaregiverConsentCopy.statusOnAnonymous), findsOneWidget);
    expect(find.textContaining('Heather'), findsNothing);
    expect(
      _tile(tester, CaregiverConsentScreen.moodRowKey).onChanged,
      isNotNull,
    );
    expect(
      _tile(tester, CaregiverConsentScreen.alertsRowKey).onChanged,
      isNotNull,
    );
    expect(
      _tile(tester, CaregiverConsentScreen.checkInsRowKey).onChanged,
      isNotNull,
    );

    await tester.tap(find.byKey(CaregiverConsentScreen.moodRowKey));
    await tester.pump();
    expect(_tile(tester, CaregiverConsentScreen.moodRowKey).value, isTrue);

    await tester.tap(find.byKey(CaregiverConsentScreen.masterSwitchKey));
    await tester.pump();

    expect(_tile(tester, CaregiverConsentScreen.masterSwitchKey).value, isFalse);
    expect(find.text(CaregiverConsentCopy.statusOff), findsOneWidget);
    expect(find.byKey(CaregiverConsentScreen.revokeKey), findsNothing);
    expect(_tile(tester, CaregiverConsentScreen.moodRowKey).onChanged, isNull);
    expect(_tile(tester, CaregiverConsentScreen.alertsRowKey).onChanged, isNull);
    expect(
      _tile(tester, CaregiverConsentScreen.checkInsRowKey).onChanged,
      isNull,
    );
  });

  testWidgets('revoke dialog resets all toggles to false', (tester) async {
    await _pumpScreen(tester);

    await tester.tap(find.byKey(CaregiverConsentScreen.masterSwitchKey));
    await tester.pump();
    await tester.tap(find.byKey(CaregiverConsentScreen.moodRowKey));
    await tester.pump();
    await tester.tap(find.byKey(CaregiverConsentScreen.alertsRowKey));
    await tester.pump();
    await tester.tap(find.byKey(CaregiverConsentScreen.checkInsRowKey));
    await tester.pump();

    expect(_tile(tester, CaregiverConsentScreen.moodRowKey).value, isTrue);
    expect(_tile(tester, CaregiverConsentScreen.alertsRowKey).value, isTrue);
    expect(_tile(tester, CaregiverConsentScreen.checkInsRowKey).value, isTrue);

    await tester.tap(find.byKey(CaregiverConsentScreen.revokeKey));
    await tester.pumpAndSettle();

    expect(find.byKey(CaregiverConsentScreen.revokeDialogKey), findsOneWidget);
    expect(find.text(CaregiverConsentCopy.revokeConfirmTitle), findsOneWidget);
    expect(find.text(CaregiverConsentCopy.revokeConfirmBody), findsOneWidget);
    expect(find.textContaining('Heather'), findsNothing);
    expect(
      find.textContaining('stop all data sharing with Heather'),
      findsNothing,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, CaregiverConsentCopy.revokeConfirmAction),
      ),
    );
    await tester.pumpAndSettle();

    expect(_tile(tester, CaregiverConsentScreen.masterSwitchKey).value, isFalse);
    expect(_tile(tester, CaregiverConsentScreen.moodRowKey).value, isFalse);
    expect(_tile(tester, CaregiverConsentScreen.alertsRowKey).value, isFalse);
    expect(_tile(tester, CaregiverConsentScreen.checkInsRowKey).value, isFalse);
    expect(find.text(CaregiverConsentCopy.statusOff), findsOneWidget);
    expect(find.byKey(CaregiverConsentScreen.revokeKey), findsNothing);
  });

  testWidgets(
    'previewMode starts connected to Heather with paste defaults',
    (tester) async {
      await _pumpScreen(tester, previewMode: true);

      expect(_tile(tester, CaregiverConsentScreen.masterSwitchKey).value, isTrue);
      expect(_tile(tester, CaregiverConsentScreen.moodRowKey).value, isTrue);
      expect(_tile(tester, CaregiverConsentScreen.alertsRowKey).value, isTrue);
      expect(_tile(tester, CaregiverConsentScreen.checkInsRowKey).value, isFalse);
      expect(
        find.text('Connected to Heather (Primary Caregiver)'),
        findsOneWidget,
      );
      expect(find.byKey(CaregiverConsentScreen.revokeKey), findsOneWidget);
    },
  );

  testWidgets(
    'previewMode revoke dialog can mention Heather',
    (tester) async {
      await _pumpScreen(tester, previewMode: true);

      await tester.tap(find.byKey(CaregiverConsentScreen.revokeKey));
      await tester.pumpAndSettle();

      expect(find.byKey(CaregiverConsentScreen.revokeDialogKey), findsOneWidget);
      expect(
        find.text(CaregiverConsentCopy.revokeConfirmBodyPreview),
        findsOneWidget,
      );
      expect(find.textContaining('Heather'), findsWidgets);
    },
  );

  testWidgets('production previewMode false does not invent Heather', (
    tester,
  ) async {
    await _pumpScreen(tester);

    await tester.tap(find.byKey(CaregiverConsentScreen.masterSwitchKey));
    await tester.pump();

    expect(find.textContaining('Heather'), findsNothing);
    expect(find.text(CaregiverConsentCopy.statusOnAnonymous), findsOneWidget);

    await tester.tap(find.byKey(CaregiverConsentScreen.revokeKey));
    await tester.pumpAndSettle();

    expect(find.textContaining('Heather'), findsNothing);
    expect(find.text(CaregiverConsentCopy.revokeConfirmBody), findsOneWidget);
    expect(
      find.textContaining('stop all data sharing with Heather'),
      findsNothing,
    );
  });

  testWidgets('explicit caregiverDisplayName is used without previewMode', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      caregiverDisplayName: 'Sam',
      caregiverRole: 'Primary Caregiver',
    );

    await tester.tap(find.byKey(CaregiverConsentScreen.masterSwitchKey));
    await tester.pump();

    expect(find.text('Connected to Sam (Primary Caregiver)'), findsOneWidget);
    expect(find.textContaining('Heather'), findsNothing);
  });
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  String? caregiverDisplayName,
  String? caregiverRole,
  bool previewMode = false,
}) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: CaregiverConsentScreen(
        caregiverDisplayName: caregiverDisplayName,
        caregiverRole: caregiverRole,
        previewMode: previewMode,
      ),
    ),
  );
  await tester.pump();
}

SwitchListTile _tile(WidgetTester tester, Key key) {
  return tester.widget<SwitchListTile>(find.byKey(key));
}
