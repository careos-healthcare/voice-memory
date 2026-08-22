import 'package:archiveme_mobile/features/archive_agreement/archive_agreement_models.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Local agreement history (metadata only).
class ArchiveAgreementStore {
  ArchiveAgreementStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _historyKey = 'archiveTheoryAgreementHistory';
  static const int maxRecords = 50;

  Future<List<ArchiveAgreementRecord>> loadHistory() async {
    final raw = await _prefs.readJsonMap(_historyKey);
    if (raw == null) return const [];
    final list = raw['records'];
    if (list is! List) return const [];

    final out = <ArchiveAgreementRecord>[];
    for (final item in list) {
      if (item is! Map) continue;
      final record = ArchiveAgreementRecord.fromJson(
        Map<String, dynamic>.from(item),
      );
      if (record != null) out.add(record);
    }
    return out;
  }

  Future<void> saveHistory(List<ArchiveAgreementRecord> records) async {
    final trimmed = records.length <= maxRecords
        ? records
        : records.sublist(0, maxRecords);
    await _prefs.writeJsonMap(_historyKey, {
      'records': trimmed.map((r) => r.toJson()).toList(),
    });
  }
}