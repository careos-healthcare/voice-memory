import 'dart:async';

import 'package:archiveme_mobile/features/fact_ledger/fact_ledger_store.dart';
import 'package:archiveme_mobile/features/recording/evidence_indexing/evidence_indexing_engine.dart';
import 'package:archiveme_mobile/features/recording/evidence_indexing/evidence_indexing_models.dart';
import 'package:archiveme_mobile/features/recording/evidence_indexing/evidence_indexing_service.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:flutter/foundation.dart';

/// Drives the live evidence indexing animation during post-save processing.
class EvidenceIndexingController extends ChangeNotifier {
  EvidenceIndexingPhase phase = EvidenceIndexingPhase.listening;
  String? stageLabel;
  String? entryId;
  final List<EvidenceIndexingChip> visibleChips = [];
  int committedAnchorCount = 0;
  var _dismissed = false;
  Completer<void>? _completionCompleter;

  bool get isComplete =>
      phase == EvidenceIndexingPhase.complete ||
      phase == EvidenceIndexingPhase.skipped;

  void reset() {
    phase = EvidenceIndexingPhase.listening;
    stageLabel = null;
    entryId = null;
    visibleChips.clear();
    committedAnchorCount = 0;
    _dismissed = false;
    _completionCompleter = null;
    notifyListeners();
  }

  void updateStageLabel(String? label) {
    stageLabel = label;
    notifyListeners();
  }

  void skip() {
    phase = EvidenceIndexingPhase.skipped;
    _completeWaiters();
    notifyListeners();
  }

  Future<void> runForEntry({
    required JournalEntry entry,
    required FactLedgerStore store,
  }) async {
    _completionCompleter = Completer<void>();
    entryId = entry.id;
    final chips = EvidenceIndexingEngine.extract(entry);

    if (chips.isEmpty) {
      phase = EvidenceIndexingPhase.skipped;
      notifyListeners();
      _autoDismissAfter(const Duration(milliseconds: 900));
      await _completionCompleter!.future;
      return;
    }

    phase = EvidenceIndexingPhase.extracting;
    notifyListeners();

    for (final chip in chips) {
      phase = EvidenceIndexingPhase.committing;
      notifyListeners();

      final committed = await EvidenceIndexingService.commitAnchor(
        entry: entry,
        chip: chip,
        store: store,
      );
      if (!committed) continue;

      committedAnchorCount++;
      visibleChips.add(chip);
      notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 360));
    }

    if (committedAnchorCount == 0) {
      phase = EvidenceIndexingPhase.skipped;
      notifyListeners();
      _autoDismissAfter(const Duration(milliseconds: 900));
      await _completionCompleter!.future;
      return;
    }

    phase = EvidenceIndexingPhase.complete;
    notifyListeners();
    _autoDismissAfter(const Duration(seconds: 4));
    await _completionCompleter!.future;
  }

  void dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    _completeWaiters();
    notifyListeners();
  }

  void _autoDismissAfter(Duration delay) {
    Future<void>.delayed(delay, () {
      if (!_dismissed) dismiss();
    });
  }

  void _completeWaiters() {
    if (_completionCompleter != null && !_completionCompleter!.isCompleted) {
      _completionCompleter!.complete();
    }
  }

  @override
  void dispose() {
    _completeWaiters();
    super.dispose();
  }
}