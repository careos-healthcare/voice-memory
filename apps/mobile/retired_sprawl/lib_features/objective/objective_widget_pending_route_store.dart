import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Stores a route to open after the user taps the home-screen widget.
class ObjectiveWidgetPendingRouteStore {
  ObjectiveWidgetPendingRouteStore(this._prefs);

  static const pendingRouteKey = 'objective_widget_pending_route';
  static const _key = pendingRouteKey;

  final MobilePrefsStore _prefs;

  static ObjectiveWidgetPendingRouteStore instance() =>
      ObjectiveWidgetPendingRouteStore(AppServices.instance.prefs);

  Future<void> savePendingRoute(String route) async {
    await _prefs.writeString(_key, route.trim());
  }

  Future<String?> loadPendingRoute() async {
    final route = await _prefs.readString(_key);
    if (route == null || route.trim().isEmpty) return null;
    return route.trim();
  }

  Future<void> clear() async {
    await _prefs.writeString(_key, '');
  }
}