import 'package:archiveme_mobile/features/archive_agreement/archive_agreement_models.dart';
import 'package:archiveme_mobile/features/archive_agreement/archive_agreement_store.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Records and reads theory agreement — metadata only, no model retraining.
class ArchiveAgreementService {
  ArchiveAgreementService(this._store);

  final ArchiveAgreementStore _store;

  static ArchiveAgreementService fromPrefs(MobilePrefsStore prefs) {
    return ArchiveAgreementService(ArchiveAgreementStore(prefs));
  }

  static String theoryKeyFor(String statement) {
    return statement.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<ArchiveAgreementRecord> record({
    required String theoryStatement,
    required ArchiveTheoryAgreementResponse response,
    int? confidencePercent,
  }) async {
    final text = theoryStatement.trim();
    final key = theoryKeyFor(text);
    final record = ArchiveAgreementRecord(
      id: 'agr_${DateTime.now().microsecondsSinceEpoch}',
      theoryStatement: text,
      theoryKey: key,
      response: response,
      recordedAt: DateTime.now(),
      confidencePercent: confidencePercent,
    );

    final history = await _store.loadHistory();
    final next = [record, ...history];
    await _store.saveHistory(next);
    return record;
  }

  Future<ArchiveAgreementHistoryView> historyForTheory({
    required String currentTheoryStatement,
    int displayLimit = 12,
  }) async {
    final all = await _store.loadHistory();
    final key = theoryKeyFor(currentTheoryStatement);
    ArchiveAgreementRecord? latest;
    for (final r in all) {
      if (r.theoryKey == key) {
        latest = r;
        break;
      }
    }
    return ArchiveAgreementHistoryView(
      records: all.take(displayLimit).toList(),
      latestForCurrentTheory: latest,
    );
  }

  Future<ArchiveTheoryAgreementResponse?> latestResponseForTheory(
    String theoryStatement,
  ) async {
    final view = await historyForTheory(
      currentTheoryStatement: theoryStatement,
      displayLimit: 1,
    );
    return view.latestForCurrentTheory?.response;
  }
}