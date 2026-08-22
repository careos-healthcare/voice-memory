import 'package:archiveme_mobile/features/tomorrow_return/change_summary_model.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

class ChangeSummaryStore {
  ChangeSummaryStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _key = 'changeSummaryLatest';

  Future<ChangeSummary?> read() async {
    final raw = await _prefs.readMap(_key);
    return ChangeSummary.fromJson(raw);
  }

  Future<void> write(ChangeSummary? summary) async {
    if (summary == null) {
      await _prefs.writeMap(_key, {});
      return;
    }
    await _prefs.writeMap(_key, summary.toJson());
  }
}