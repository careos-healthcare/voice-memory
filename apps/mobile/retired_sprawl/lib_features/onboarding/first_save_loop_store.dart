import 'package:archiveme_mobile/features/onboarding/record_return_pro_state.dart';
import 'package:archiveme_mobile/features/onboarding/record_return_pro_store.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Legacy alias store — delegates to [RecordReturnProStore].
class FirstSaveLoopStore {
  FirstSaveLoopStore({MobilePrefsStore? prefs})
    : _delegate = RecordReturnProStore(prefs: prefs);

  static FirstSaveLoopStore instance() => FirstSaveLoopStore();

  /// Legacy prefs key — migration reads this in [RecordReturnProStore.load].
  static const String prefsKey = 'firstSaveLoop';

  final RecordReturnProStore _delegate;

  Future<RecordReturnProState> load() => _delegate.load();

  Future<void> markReturnCueResolved(String method) =>
      _delegate.markReturnCueResolved(method);

  Future<void> markProBridgeResolved() => _delegate.markProBridgeResolved();
}