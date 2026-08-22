import 'dart:async';

import 'package:archiveme_mobile/features/archive_home/evidence_ledger_models.dart';
import 'package:archiveme_mobile/features/fact_ledger/fact_ledger_sqlite_repository.dart';
import 'package:archiveme_mobile/features/fact_ledger/fact_ledger_store.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:flutter/foundation.dart';

/// Live SQLite-backed counts for the evidence ledger header badge.
class EvidenceLedgerCountController extends ChangeNotifier {
  EvidenceLedgerCountController._();

  static final EvidenceLedgerCountController instance =
      EvidenceLedgerCountController._();

  EvidenceLedgerCounts _counts = const EvidenceLedgerCounts.empty();
  bool _refreshInFlight = false;

  EvidenceLedgerCounts get counts => _counts;

  Future<void> refresh() async {
    if (_refreshInFlight) return;
    _refreshInFlight = true;
    try {
      if (!AppServices.isInitialized) {
        _applyCounts(const EvidenceLedgerCounts.empty());
        return;
      }

      final sqlite = AppServices.instance.sqliteDatabase;
      final repository = FactLedgerSqliteRepository.fromAppServicesDatabase(
        sqlite,
      );
      if (repository == null) {
        await _refreshFromPrefs();
        return;
      }

      await repository.ensureBackfilledFromPrefs(AppServices.instance.prefs);
      final citableFactCount = await repository.countFacts();
      final entryCount = await repository.countDistinctEntries();
      _applyCounts(
        EvidenceLedgerCounts(
          citableFactCount: citableFactCount,
          entryCount: entryCount,
        ),
      );
    } finally {
      _refreshInFlight = false;
    }
  }

  Future<void> _refreshFromPrefs() async {
    final facts = await FactLedgerStore(AppServices.instance.prefs).loadAll();
    final entryIds = facts.map((fact) => fact.sourceEntryId).toSet();
    _applyCounts(
      EvidenceLedgerCounts(
        citableFactCount: facts.length,
        entryCount: entryIds.length,
      ),
    );
  }

  void _applyCounts(EvidenceLedgerCounts next) {
    if (_counts.citableFactCount == next.citableFactCount &&
        _counts.entryCount == next.entryCount) {
      return;
    }
    _counts = next;
    notifyListeners();
  }

  /// Test-only reset between cases.
  @visibleForTesting
  void resetForTest() {
    _counts = const EvidenceLedgerCounts.empty();
    _refreshInFlight = false;
    notifyListeners();
  }
}

/// Notifies the count controller after fact ledger writes.
void notifyEvidenceLedgerCountsChanged() {
  unawaited(EvidenceLedgerCountController.instance.refresh());
}