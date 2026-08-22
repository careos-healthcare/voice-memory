import 'package:archiveme_mobile/features/auth/application/multi_party_access_service.dart';
import 'package:archiveme_mobile/features/auth/domain/multi_party_access_grant.dart';
import 'package:archiveme_mobile/features/auth/infrastructure/consent_revocation_store.dart';
import 'package:archiveme_mobile/features/settings/ui/consent_management_panel.dart';
import 'package:archiveme_mobile/features/settings/ui/consent_management_panel_copy.dart';
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
  group('ConsentManagementPanel', () {
    testWidgets('shows helper text and revoke buttons for active grants', (
      tester,
    ) async {
      final service = _StubMultiPartyAccessService(
        prefs: await MobilePrefsStore.open(
          'test/tmp/consent_panel/prefs.json',
        ),
        grants: [
          MultiPartyAccessGrant(
            grantId: 'grant-1',
            partyId: 'observer-ada',
            role: MultiPartyAccessRole.observer,
            grantedAt: DateTime.utc(2026, 6, 1),
          ),
          MultiPartyAccessGrant(
            grantId: 'grant-2',
            partyId: 'caregiver-sam',
            role: MultiPartyAccessRole.caregiver,
            grantedAt: DateTime.utc(2026, 5, 1),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ConsentManagementPanel(
              accessService: service,
              confirmRevokeOverride: (_, __) async => true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(ConsentManagementPanel.panelKey), findsOneWidget);
      expect(
        find.text(ConsentManagementPanelCopy.helperText),
        findsOneWidget,
      );
      expect(find.text('observer-ada'), findsOneWidget);
      expect(find.text('caregiver-sam'), findsOneWidget);
      expect(find.text(ConsentManagementPanelCopy.revokeAccessCta), findsNWidgets(2));

      await tester.tap(find.byKey(const Key('consent_revoke_access_grant-1')));
      await tester.pumpAndSettle();

      expect(service.revoked, ['grant-1']);
      expect(find.text('observer-ada'), findsNothing);
      expect(find.text('caregiver-sam'), findsOneWidget);
    });

    testWidgets('shows empty state when no grants', (tester) async {
      final service = _StubMultiPartyAccessService(
        prefs: await MobilePrefsStore.open(
          'test/tmp/consent_panel_empty/prefs.json',
        ),
        grants: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ConsentManagementPanel(accessService: service),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('consent_management_empty')), findsOneWidget);
    });
  });

  tearDown(() async {
    await ConsentRevocationStore.resetForTest();
  });
}
