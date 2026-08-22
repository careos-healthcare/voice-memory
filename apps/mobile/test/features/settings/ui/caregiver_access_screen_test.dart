import 'package:archiveme_mobile/features/auth/application/multi_party_access_service.dart';
import 'package:archiveme_mobile/features/auth/domain/caregiver_access_copy.dart';
import 'package:archiveme_mobile/features/auth/domain/multi_party_access_grant.dart';
import 'package:archiveme_mobile/features/auth/infrastructure/consent_revocation_store.dart';
import 'package:archiveme_mobile/features/settings/ui/caregiver_access_screen.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubMultiPartyAccessService extends MultiPartyAccessService {
  _StubMultiPartyAccessService({
    required this.grants,
    required MobilePrefsStore prefs,
  }) : super(prefs: prefs);

  List<MultiPartyAccessGrant> grants;
  final revoked = <String>[];

  @override
  Future<List<MultiPartyAccessGrant>> loadActiveGrants({DateTime? now}) async {
    return grants;
  }

  @override
  Future<void> revokeGrant(MultiPartyAccessGrant grant) async {
    revoked.add(grant.grantId);
    grants = grants.where((g) => g.grantId != grant.grantId).toList();
  }
}

void main() {
  group('CaregiverAccessScreen', () {
    testWidgets('shows control copy, boundaries, and inline revoke buttons', (
      tester,
    ) async {
      final service = _StubMultiPartyAccessService(
        prefs: await MobilePrefsStore.open(
          'test/tmp/caregiver_access_screen/prefs.json',
        ),
        grants: [
          MultiPartyAccessGrant(
            grantId: 'grant-1',
            partyId: 'caregiver-sam',
            role: MultiPartyAccessRole.caregiver,
            grantedAt: DateTime.utc(2026, 6, 1),
          ),
          MultiPartyAccessGrant(
            grantId: 'grant-2',
            partyId: 'observer-ada',
            role: MultiPartyAccessRole.observer,
            grantedAt: DateTime.utc(2026, 5, 1),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: CaregiverAccessScreen(
            accessService: service,
            confirmRevokeOverride: (_, __) async => true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(CaregiverAccessScreen.screenKey), findsOneWidget);
      expect(find.byKey(const Key('caregiver_access_control_callout')),
          findsOneWidget);
      expect(find.text(CaregiverAccessCopy.controlHeading), findsOneWidget);
      expect(find.text(CaregiverAccessCopy.canSeeHeading), findsOneWidget);
      expect(find.text(CaregiverAccessCopy.cannotSeeHeading), findsOneWidget);
      expect(find.text(CaregiverAccessCopy.cannotDoHeading), findsOneWidget);
      expect(find.text(CaregiverAccessCopy.caregiverCanSeeTitle), findsOneWidget);
      expect(find.text(CaregiverAccessCopy.observerCanSeeTitle), findsOneWidget);
      expect(find.text('caregiver-sam'), findsOneWidget);
      expect(find.text('observer-ada'), findsOneWidget);
      expect(find.text(CaregiverAccessCopy.revokeAccessCta), findsNWidgets(2));

      await tester.tap(find.byKey(const Key('caregiver_access_revoke_grant-1')));
      await tester.pumpAndSettle();

      expect(service.revoked, ['grant-1']);
      expect(find.text('caregiver-sam'), findsNothing);
      expect(find.text('observer-ada'), findsOneWidget);
    });

    testWidgets('shows empty grants message when none are active', (
      tester,
    ) async {
      final service = _StubMultiPartyAccessService(
        prefs: await MobilePrefsStore.open(
          'test/tmp/caregiver_access_screen_empty/prefs.json',
        ),
        grants: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: CaregiverAccessScreen(accessService: service),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('caregiver_access_grants_empty')),
          findsOneWidget);
    });
  });

  tearDown(() async {
    await ConsentRevocationStore.resetForTest();
  });
}
