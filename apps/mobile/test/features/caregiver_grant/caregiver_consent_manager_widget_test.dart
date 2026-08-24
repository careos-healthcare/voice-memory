import 'package:archiveme_mobile/features/auth/application/multi_party_access_service.dart';
import 'package:archiveme_mobile/features/auth/domain/consent_revocation_outcome.dart';
import 'package:archiveme_mobile/features/auth/domain/multi_party_access_grant.dart';
import 'package:archiveme_mobile/features/caregiver_grant/caregiver_consent_manager_widget.dart';
import 'package:archiveme_mobile/features/settings/ui/caregiver_access_screen.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/app_provider_scope.dart';

class _StubAccessService extends MultiPartyAccessService {
  @override
  Future<List<MultiPartyAccessGrant>> loadActiveGrants({DateTime? now}) async {
    return const [];
  }

  @override
  Future<ConsentRevocationOutcome> revokeGrant(
    MultiPartyAccessGrant grant,
  ) async {
    return const ConsentRevocationOutcome(
      localRevoked: true,
      serverConfirmed: true,
      queuedForRetry: false,
    );
  }
}

void main() {
  testWidgets(
    'CaregiverConsentManagerWidget redirects to CaregiverAccessScreen',
    (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        withAppProviderScope(
          MaterialApp(
            theme: AppTheme.light(),
            home: CaregiverConsentManagerWidget(
              accessService: _StubAccessService(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(CaregiverConsentManagerWidget.widgetKey),
        findsOneWidget,
      );
      expect(find.byKey(CaregiverAccessScreen.screenKey), findsOneWidget);
    },
  );
}
