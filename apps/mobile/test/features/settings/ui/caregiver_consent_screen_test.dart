import 'package:archiveme_mobile/features/auth/application/multi_party_access_service.dart';
import 'package:archiveme_mobile/features/auth/domain/consent_revocation_outcome.dart';
import 'package:archiveme_mobile/features/auth/domain/multi_party_access_grant.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_feature_flags.dart';
import 'package:archiveme_mobile/features/caregiver_grant/caregiver_grant_disclosure_screen.dart';
import 'package:archiveme_mobile/features/settings/presentation/caregiver_consent_copy.dart';
import 'package:archiveme_mobile/features/settings/presentation/caregiver_consent_screen.dart';
import 'package:archiveme_mobile/security/privacy_copy_policy.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/app_provider_scope.dart';

class _StubAccessService extends MultiPartyAccessService {
  _StubAccessService({this.grants = const []});

  List<MultiPartyAccessGrant> grants;
  final revoked = <String>[];

  @override
  Future<List<MultiPartyAccessGrant>> loadActiveGrants({DateTime? now}) async {
    return grants;
  }

  @override
  Future<ConsentRevocationOutcome> revokeGrant(
    MultiPartyAccessGrant grant,
  ) async {
    revoked.add(grant.grantId);
    grants = grants.where((item) => item.grantId != grant.grantId).toList();
    return const ConsentRevocationOutcome(
      localRevoked: true,
      serverConfirmed: true,
      queuedForRetry: false,
    );
  }
}

void main() {
  tearDown(() => CaregiverFeatureFlags.debugOverride = null);

  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    required _StubAccessService service,
    Future<bool> Function(BuildContext context)? confirmRevoke,
  }) async {
    CaregiverFeatureFlags.debugOverride = true;
    useTallSurface(tester);
    await tester.pumpWidget(
      withAppProviderScope(
        MaterialApp(
          theme: AppTheme.light(),
          home: CaregiverConsentScreen(
            accessService: service,
            confirmRevokeOverride: confirmRevoke,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  test('copy names opening words and a local-then-server revoke', () {
    expect(CaregiverConsentCopy.banner, contains('opening words'));
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
    expect(CaregiverConsentCopy.revokeConfirmBody, contains('this device'));
    expect(CaregiverConsentCopy.revokeConfirmBody, contains('server'));
    expect(CaregiverConsentCopy.settingsTileTitle, 'Caregiver Access & Consent');
    expect(CaregiverConsentCopy.screenTitle, 'Caregiver Access & Consent');
    expect(CaregiverConsentCopy.statusOff, 'Not Connected');
    expect(CaregiverConsentCopy.revokeCta, 'Revoke All Caregiver Access');
    expect(
      CaregiverConsentCopy.statusOn(partyLabels: const ['Sam']),
      'Connected to Sam',
    );
  });

  test('statusOn uses the grant display name and never hard-codes Heather', () {
    expect(
      CaregiverConsentCopy.statusOn(partyLabels: const ['Sam']),
      'Connected to Sam',
    );
    expect(
      CaregiverConsentCopy.statusOn(partyLabels: const []),
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
      CaregiverConsentCopy.sharingOptionsHeading,
      CaregiverConsentCopy.moodTitle,
      CaregiverConsentCopy.moodBody,
      CaregiverConsentCopy.alertsTitle,
      CaregiverConsentCopy.alertsBody,
      CaregiverConsentCopy.checkInsTitle,
      CaregiverConsentCopy.checkInsBody,
      CaregiverConsentCopy.unavailableInThisVersion,
      CaregiverConsentCopy.revokeCta,
      CaregiverConsentCopy.revokeDisabled,
      CaregiverConsentCopy.revokeConfirmTitle,
      CaregiverConsentCopy.revokeConfirmBody,
      CaregiverConsentCopy.revokeCancel,
      CaregiverConsentCopy.statusOn(partyLabels: const ['Sam']),
    ]) {
      final violations = PrivacyCopyPolicy.violationsInLiteral(line);
      if (violations.isNotEmpty) offenders[line] = violations;
    }
    expect(offenders, isEmpty);
  });

  testWidgets('shows title, shield banner, master control, and revoke', (
    tester,
  ) async {
    await pumpScreen(tester, service: _StubAccessService());

    expect(find.byKey(CaregiverConsentScreen.screenKey), findsOneWidget);
    expect(find.text(CaregiverConsentCopy.screenTitle), findsOneWidget);
    expect(find.byKey(CaregiverConsentScreen.bannerKey), findsOneWidget);
    expect(find.byKey(CaregiverConsentScreen.shieldKey), findsOneWidget);
    expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
    expect(find.text(CaregiverConsentCopy.banner), findsOneWidget);
    expect(find.byKey(CaregiverConsentScreen.masterSwitchKey), findsOneWidget);
    expect(find.text(CaregiverConsentCopy.masterTitle), findsOneWidget);
    expect(find.text(CaregiverConsentCopy.statusOff), findsOneWidget);
    expect(find.byKey(CaregiverConsentScreen.revokeKey), findsOneWidget);
    expect(find.text(CaregiverConsentCopy.revokeCta), findsOneWidget);
    expect(find.text(CaregiverConsentCopy.revokeDisabled), findsOneWidget);
  });

  testWidgets('granular rows are disabled labels, not live switches', (
    tester,
  ) async {
    await pumpScreen(tester, service: _StubAccessService());

    expect(find.byType(SwitchListTile), findsOneWidget);
    expect(find.byKey(CaregiverConsentScreen.moodRowKey), findsOneWidget);
    expect(find.byKey(CaregiverConsentScreen.alertsRowKey), findsOneWidget);
    expect(find.byKey(CaregiverConsentScreen.checkInsRowKey), findsOneWidget);
    expect(find.text(CaregiverConsentCopy.moodTitle), findsOneWidget);
    expect(find.text(CaregiverConsentCopy.alertsTitle), findsOneWidget);
    expect(find.text(CaregiverConsentCopy.checkInsTitle), findsOneWidget);
    expect(find.text(CaregiverConsentCopy.moodBody), findsOneWidget);
    expect(find.text(CaregiverConsentCopy.alertsBody), findsOneWidget);
    expect(find.text(CaregiverConsentCopy.checkInsBody), findsOneWidget);
    expect(find.textContaining(CaregiverConsentCopy.unavailableInThisVersion), findsNWidgets(3));

    for (final key in [
      CaregiverConsentScreen.moodRowKey,
      CaregiverConsentScreen.alertsRowKey,
      CaregiverConsentScreen.checkInsRowKey,
    ]) {
      expect(
        find.descendant(of: find.byKey(key), matching: find.byType(Switch)),
        findsNothing,
      );
      final tile = tester.widget<ListTile>(find.byKey(key));
      expect(tile.enabled, isFalse);
      expect(tile.onTap, isNull);
    }
  });

  testWidgets('turning the master switch on starts the grant flow', (
    tester,
  ) async {
    await pumpScreen(tester, service: _StubAccessService());

    await tester.tap(find.byKey(CaregiverConsentScreen.masterSwitchKey));
    await tester.pumpAndSettle();

    expect(find.byKey(CaregiverDisclosureScreen.screenKey), findsOneWidget);
  });

  testWidgets('revoke is disabled when there is no grant', (tester) async {
    await pumpScreen(tester, service: _StubAccessService());

    final button = tester.widget<OutlinedButton>(
      find.byKey(CaregiverConsentScreen.revokeKey),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('revoke uses the live grant path when a grant exists', (
    tester,
  ) async {
    final service = _StubAccessService(
      grants: [
        MultiPartyAccessGrant(
          grantId: 'grant-1',
          partyId: 'caregiver-sam',
          role: MultiPartyAccessRole.caregiver,
          grantedAt: DateTime.utc(2026, 6),
        ),
      ],
    );

    await pumpScreen(
      tester,
      service: service,
      confirmRevoke: (_) async => true,
    );

    expect(find.text('Connected to caregiver-sam'), findsOneWidget);
    expect(find.text('Heather'), findsNothing);

    final switchTile = tester.widget<SwitchListTile>(
      find.byKey(CaregiverConsentScreen.masterSwitchKey),
    );
    expect(switchTile.value, isTrue);

    await tester.tap(find.byKey(CaregiverConsentScreen.revokeKey));
    await tester.pumpAndSettle();

    expect(service.revoked, ['grant-1']);
    expect(find.text(CaregiverConsentCopy.statusOff), findsOneWidget);
  });

  testWidgets('turning the master switch off revokes the live grant', (
    tester,
  ) async {
    final service = _StubAccessService(
      grants: [
        MultiPartyAccessGrant(
          grantId: 'grant-2',
          partyId: 'caregiver-sam',
          role: MultiPartyAccessRole.caregiver,
          grantedAt: DateTime.utc(2026, 6),
        ),
      ],
    );

    await pumpScreen(
      tester,
      service: service,
      confirmRevoke: (_) async => true,
    );

    await tester.tap(find.byKey(CaregiverConsentScreen.masterSwitchKey));
    await tester.pumpAndSettle();

    expect(service.revoked, ['grant-2']);
    expect(find.text(CaregiverConsentCopy.statusOff), findsOneWidget);
  });
}
