import 'package:archiveme_mobile/features/settings/presentation/caregiver_consent_copy.dart';
import 'package:archiveme_mobile/features/settings/presentation/caregiver_consent_screen.dart';
import 'package:archiveme_mobile/security/privacy_copy_policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('copy names opening words and a local revoke', () {
    expect(CaregiverConsentCopy.banner, contains('opening words'));
    expect(CaregiverConsentCopy.banner, contains('Raw audio stays on this phone'));
    expect(CaregiverConsentCopy.banner, contains('unless you choose'));
    expect(CaregiverConsentCopy.banner.toLowerCase(), isNot(contains('strictly')));
    expect(
      CaregiverConsentCopy.banner.toLowerCase(),
      isNot(contains('never leaves')),
    );
    expect(
      CaregiverConsentCopy.banner.toLowerCase(),
      isNot(contains('100%')),
    );
    expect(
      CaregiverConsentCopy.banner.toLowerCase(),
      isNot(contains('summarized trend')),
    );
    expect(CaregiverConsentCopy.revokeConfirmBody, contains('stop sharing'));
    expect(CaregiverConsentCopy.revokeConfirmBody, isNot(contains('Heather')));
    expect(CaregiverConsentCopy.settingsTileTitle, 'Caregiver Access & Permissions');
    expect(CaregiverConsentCopy.screenTitle, 'Caregiver Access & Permissions');
    expect(CaregiverConsentCopy.statusOff, 'Sharing disabled');
    expect(CaregiverConsentCopy.revokeCta, 'Revoke All Caregiver Access');
    expect(
      CaregiverConsentCopy.connectedStatus(caregiverDisplayName: 'Sam'),
      'Connected to Sam',
    );
  });

  test('connectedStatus uses the passed name and never hard-codes Heather', () {
    expect(
      CaregiverConsentCopy.connectedStatus(caregiverDisplayName: 'Sam'),
      'Connected to Sam',
    );
    expect(
      CaregiverConsentCopy.connectedStatus(),
      CaregiverConsentCopy.statusOnAnonymous,
    );
    expect(CaregiverConsentCopy.statusOnAnonymous, isNot(contains('Heather')));
    expect(CaregiverConsentCopy.statusOff, isNot(contains('Heather')));
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
    ]) {
      final violations = PrivacyCopyPolicy.violationsInLiteral(line);
      if (violations.isNotEmpty) offenders[line] = violations;
    }
    expect(offenders, isEmpty);
  });

  testWidgets('ui export pumps the standalone consent screen', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: CaregiverConsentScreen(previewMode: false),
      ),
    );
    await tester.pump();

    expect(find.byKey(CaregiverConsentScreen.screenKey), findsOneWidget);
    expect(find.text(CaregiverConsentCopy.banner), findsOneWidget);
    expect(find.byKey(CaregiverConsentScreen.masterSwitchKey), findsOneWidget);
    expect(find.byKey(CaregiverConsentScreen.revokeKey), findsNothing);
    expect(find.textContaining('Heather'), findsNothing);
  });
}
