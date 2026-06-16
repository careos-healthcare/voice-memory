/// Account-screen copy for the compact privacy and control shortcuts.
import 'privacy_copy_policy.dart';

abstract class AccountPrivacyControlsCopy {
  AccountPrivacyControlsCopy._();

  static const String sectionTitle = 'Privacy and control';

  static const String lockBase = PrivacyCopyPolicy.lockArchiveMe;
  static const String lockOn = '$lockBase — On';
  static const String lockOff = '$lockBase — Off';

  static const String exportTitle = 'Export my archive';
  static const String deleteTitle = 'Delete my archive';
  static const String securitySettingsTitle = 'Security settings';

  static String lockLabel({required bool enabled}) =>
      enabled ? lockOn : lockOff;
}
