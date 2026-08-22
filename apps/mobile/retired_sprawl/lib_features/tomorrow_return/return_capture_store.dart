import 'package:archiveme_mobile/config/screenshot_mode.dart';
import 'package:archiveme_mobile/features/tomorrow_return/return_capture_model.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Lightweight pending quick-answer context before return-day recording.
class ReturnCaptureStore {
  ReturnCaptureStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _key = 'return_capture_latest_selection';

  static ReturnCaptureStore instance() =>
      ReturnCaptureStore(AppServices.instance.prefs);

  Future<void> saveSelection(ReturnCaptureSelection selection) async {
    if (ScreenshotMode.enabled) return;
    await _prefs.writeMap(_key, selection.toJson());
  }

  Future<ReturnCaptureSelection?> loadLatest() async {
    if (ScreenshotMode.enabled) {
      return ScreenshotMode.returnCaptureSelection;
    }
    final map = await _prefs.readMap(_key);
    if (map == null || map.isEmpty) return null;
    return ReturnCaptureSelection.fromJson(map);
  }

  Future<void> clear() async {
    if (ScreenshotMode.enabled) return;
    await _prefs.writeMap(_key, {});
  }
}