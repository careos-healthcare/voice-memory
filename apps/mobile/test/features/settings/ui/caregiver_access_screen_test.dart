import 'package:archiveme_mobile/features/auth/application/multi_party_access_service.dart';
import 'package:archiveme_mobile/features/auth/domain/caregiver_access_copy.dart';
import 'package:archiveme_mobile/features/auth/domain/consent_revocation_outcome.dart';
import 'package:archiveme_mobile/features/auth/domain/multi_party_access_grant.dart';
import 'package:archiveme_mobile/features/auth/infrastructure/consent_revocation_store.dart';
import 'package:archiveme_mobile/features/privacy/privacy_security_engagement_analytics.dart';
import 'package:archiveme_mobile/features/settings/ui/caregiver_access_screen.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/app_provider_scope.dart';

/// Overrides both data methods, so the base class never reaches prefs.
///
/// The previous version awaited `MobilePrefsStore.open` inside the `testWidgets`
/// body. That is real `dart:io` work in the fake-async zone, so the future never
/// completed and every case in this file hit the 10-minute test timeout.
class _StubMultiPartyAccessService extends MultiPartyAccessService {
  _StubMultiPartyAccessService({required this.grants});

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
    grants = grants.where((g) => g.grantId != grant.grantId).toList();
    return const ConsentRevocationOutcome(
      localRevoked: true,
      serverConfirmed: true,
      queuedForRetry: false,
    );
  }
}

void main() {
  tearDown(() async {
    await ConsentRevocationStore.resetForTest();
  });

  /// The screen is a lazy [ListView] taller than the default 800x600 test
  /// surface, so the grants list and the audit link are never built at the
  /// default size and no finder can see them. A tall surface keeps these cases
  /// about the copy rather than about scroll mechanics.
  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  group('CaregiverAccessScreen', () {
    testWidgets('shows control copy, boundaries, and inline revoke buttons', (
      tester,
    ) async {
      final service = _StubMultiPartyAccessService(
        grants: [
          MultiPartyAccessGrant(
            grantId: 'grant-1',
            partyId: 'caregiver-sam',
            role: MultiPartyAccessRole.caregiver,
            grantedAt: DateTime.utc(2026, 6),
          ),
          MultiPartyAccessGrant(
            grantId: 'grant-2',
            partyId: 'coach-ada',
            role: MultiPartyAccessRole.coach,
            grantedAt: DateTime.utc(2026, 5),
          ),
        ],
      );

      useTallSurface(tester);
      await tester.pumpWidget(
        withAppProviderScope(
          MaterialApp(
            theme: AppTheme.light(),
            home: CaregiverAccessScreen(
              accessService: service,
              confirmRevokeOverride: (_, _) async => true,
            ),
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
      expect(find.text(CaregiverAccessCopy.caregiverCanSeeTitle), findsOneWidget);
      expect(find.text(CaregiverAccessCopy.coachCanSeeTitle), findsOneWidget);
      expect(find.text('caregiver-sam'), findsOneWidget);
      expect(find.text('coach-ada'), findsOneWidget);
      expect(find.text(CaregiverAccessCopy.revokeAccessCta), findsNWidgets(2));

      await tester.tap(find.byKey(const Key('caregiver_access_revoke_grant-1')));
      await tester.pumpAndSettle();

      expect(service.revoked, ['grant-1']);
      expect(find.text('caregiver-sam'), findsNothing);
      expect(find.text('coach-ada'), findsOneWidget);
    });

    testWidgets('revoking here emits the caregiver_token_revoked event', (
      tester,
    ) async {
      // `CaregiverConsentManagerWidget` used to be the only emitter. Once the
      // Privacy & Security screen links here instead of mounting that widget,
      // this path is the only one left, so the funnel has to survive here.
      final events = <String, Map<String, Object>>{};
      PrivacySecurityEngagementAnalytics.captureForTest =
          (event, properties) => events[event] = properties;
      addTearDown(
        () => PrivacySecurityEngagementAnalytics.captureForTest = null,
      );

      final service = _StubMultiPartyAccessService(
        grants: [
          MultiPartyAccessGrant(
            grantId: 'grant-analytics',
            partyId: 'caregiver-sam',
            role: MultiPartyAccessRole.caregiver,
            grantedAt: DateTime.utc(2026, 6),
          ),
        ],
      );

      useTallSurface(tester);
      await tester.pumpWidget(
        withAppProviderScope(
          MaterialApp(
            theme: AppTheme.light(),
            home: CaregiverAccessScreen(
              accessService: service,
              confirmRevokeOverride: (_, _) async => true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('caregiver_access_revoke_grant-analytics')),
      );
      await tester.pumpAndSettle();

      expect(
        events[PrivacySecurityEngagementAnalytics.caregiverTokenRevokedEvent],
        {'token_id': 'grant-analytics'},
      );
    });

    testWidgets('shows empty grants message when none are active', (
      tester,
    ) async {
      final service = _StubMultiPartyAccessService(grants: const []);

      useTallSurface(tester);
      await tester.pumpWidget(
        withAppProviderScope(
          MaterialApp(
            theme: AppTheme.light(),
            home: CaregiverAccessScreen(accessService: service),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('caregiver_access_grants_empty')),
          findsOneWidget);
    });

    testWidgets('names only the roles the app constructs', (tester) async {
      final service = _StubMultiPartyAccessService(grants: const []);

      useTallSurface(tester);
      await tester.pumpWidget(
        withAppProviderScope(
          MaterialApp(
            theme: AppTheme.light(),
            home: CaregiverAccessScreen(accessService: service),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final rendered = tester
          .widgetList<Text>(find.byType(Text))
          .map((widget) => widget.data ?? '')
          .join('\n')
          .toLowerCase();

      // `MultiPartyAccessRole.observer` has no writer in lib/ — naming it in
      // copy would describe a role the product cannot grant.
      expect(rendered, isNot(contains('observer')));
    });

    testWidgets('states revocation is device-scoped, not an end to access', (
      tester,
    ) async {
      final service = _StubMultiPartyAccessService(grants: const []);

      useTallSurface(tester);
      await tester.pumpWidget(
        withAppProviderScope(
          MaterialApp(
            theme: AppTheme.light(),
            home: CaregiverAccessScreen(accessService: service),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The server `verify` route consults no revocation list, so a held token
      // survives a revoke until it expires. The confirm copy has to say so.
      expect(
        CaregiverAccessCopy.revokeConfirmBody.toLowerCase(),
        contains('on this device'),
      );
      expect(
        CaregiverAccessCopy.revokeConfirmBody.toLowerCase(),
        contains('expiry date'),
      );
      expect(
        CaregiverAccessCopy.revokeConfirmBody.toLowerCase(),
        isNot(contains('immediately ends access')),
      );

      // Read-only limits are no longer UI-absence: export, capture and audio
      // playback run `CaregiverSessionGuard`. The copy names the check and
      // keeps the scope on the sentence, because no server enforces it.
      final intent = CaregiverAccessCopy.intentBody.toLowerCase();
      expect(intent, contains('on this device'));
      expect(intent, contains('permission check'));
      expect(intent, contains('not on a server'));
      expect(intent, isNot(contains('rather than from a permission check')));
      expect(intent, isNot(contains('intent rather than a guarantee')));
      expect(
        CaregiverAccessCopy.intentHeading.toLowerCase(),
        contains('this device'),
      );
      final boundaries = [
        ...CaregiverAccessCopy.cannotSeeBullets,
        CaregiverAccessCopy.controlBody,
      ].join(' ').toLowerCase();
      expect(boundaries, isNot(contains('export')));
    });

    testWidgets('links out to the consent audit trail rather than absorbing it',
        (tester) async {
      final service = _StubMultiPartyAccessService(grants: const []);
      final router = GoRouter(
        initialLocation: '/caregiver-access',
        routes: [
          GoRoute(
            path: '/caregiver-access',
            builder: (context, state) =>
                CaregiverAccessScreen(accessService: service),
          ),
          GoRoute(
            path: '/consent-audit',
            builder: (context, state) => const Scaffold(
              key: Key('consent_audit_screen_stub'),
              body: Text('Consent audit'),
            ),
          ),
        ],
      );

      useTallSurface(tester);
      await tester.pumpWidget(
        withAppProviderScope(
          MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      final link = find.byKey(const Key('caregiver_access_consent_audit_link'));
      expect(link, findsOneWidget);
      await tester.tap(link);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('consent_audit_screen_stub')),
        findsOneWidget,
      );
    });
  });
}
