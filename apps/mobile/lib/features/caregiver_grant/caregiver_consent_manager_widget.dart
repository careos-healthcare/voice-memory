import 'package:archiveme_mobile/features/auth/application/multi_party_access_service.dart';
import 'package:archiveme_mobile/features/settings/ui/caregiver_access_screen.dart';
import 'package:flutter/material.dart';

/// Former consent-management panel — redirects to the canonical screen.
///
/// `ConsentManagementPanel` was deleted. This widget exists so leftover
/// imports do not resurrect that surface. It renders [CaregiverAccessScreen],
/// which is the live grant-list and revoke path.
class CaregiverConsentManagerWidget extends StatelessWidget {
  const CaregiverConsentManagerWidget({super.key, this.accessService});

  final MultiPartyAccessService? accessService;

  static const Key widgetKey = Key('caregiver_consent_manager_widget');

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: widgetKey,
      child: CaregiverAccessScreen(accessService: accessService),
    );
  }
}
