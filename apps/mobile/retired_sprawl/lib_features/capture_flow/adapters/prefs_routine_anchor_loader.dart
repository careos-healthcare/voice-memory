import 'package:archiveme_mobile/features/capture_flow/interfaces/capture_flow_ports.dart';
import 'package:archiveme_mobile/features/routine/routine_anchor_model.dart';
import 'package:archiveme_mobile/features/routine/routine_anchor_store.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

class PrefsRoutineAnchorLoader implements RoutineAnchorLoader {
  PrefsRoutineAnchorLoader(this._prefs);

  final MobilePrefsStore _prefs;

  @override
  Future<RoutineAnchor?> loadLatest() =>
      RoutineAnchorStore(_prefs).loadLatest();
}
