import 'package:archiveme_mobile/features/settings/presentation/caregiver_consent_copy.dart';
import 'package:archiveme_mobile/features/settings/presentation/caregiver_consent_screen.dart';
import 'package:archiveme_mobile/features/settings/ui/caregiver_consent_screen.dart'
    as ui_export;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CaregiverConsentScreen is exported from settings/presentation', () {
    expect(CaregiverConsentScreen.screenKey, const Key('caregiver_consent_screen'));
    expect(identical(CaregiverConsentScreen, ui_export.CaregiverConsentScreen), isTrue);
    expect(CaregiverConsentCopy.settingsTileTitle, 'Caregiver Access & Consent');
    expect(CaregiverConsentCopy.revokeCta, 'Revoke All Caregiver Access');
    expect(CaregiverConsentCopy.statusOff, 'Not Connected');
  });
}
