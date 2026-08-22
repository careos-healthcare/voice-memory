import 'package:archiveme_mobile/services/app_services.dart';

/// Local dismiss state for the archive-home Pro value preview promo.
abstract final class ProValuePreviewDismissStore {
  ProValuePreviewDismissStore._();

  static const prefsKey = 'proValuePreviewPromoDismissed';

  static bool _dismissed = false;
  static bool _loaded = false;

  static bool get isDismissed => _dismissed;

  static Future<void> ensureLoaded() async {
    if (_loaded || !AppServices.isInitialized) return;
    final value = await AppServices.instance.prefs.readBool(prefsKey);
    _dismissed = value == true;
    _loaded = true;
  }

  static Future<void> dismiss() async {
    _dismissed = true;
    _loaded = true;
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeBool(prefsKey, true);
  }

  static Future<void> resetForTest() async {
    _dismissed = false;
    _loaded = false;
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeBool(prefsKey, false);
  }
}