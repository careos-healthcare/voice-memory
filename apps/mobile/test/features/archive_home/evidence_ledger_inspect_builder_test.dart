import 'package:archiveme_mobile/features/archive_home/evidence_ledger_inspect_builder.dart';
import 'package:archiveme_mobile/features/archive_home/evidence_ledger_models.dart';
import 'package:archiveme_mobile/features/pattern_match_quality/pattern_match_quality_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EvidenceLedgerInspectFilter', () {
    final items = [
      EvidenceLedgerInspectItem(
        id: 'strong',
        kind: EvidenceLedgerItemKind.belief,
        title: 'I avoid hard conversations',
        subtitle: '3 supporting entries',
        confidenceBand: PatternMatchConfidenceBand.strong,
        referenceDate: DateTime(2026, 8),
      ),
      EvidenceLedgerInspectItem(
        id: 'weak',
        kind: EvidenceLedgerItemKind.blindSpot,
        title: 'Sleep routine',
        subtitle: 'Rarely mentioned after midnight',
        confidenceBand: PatternMatchConfidenceBand.weak,
        referenceDate: DateTime(2026),
      ),
    ];

    test('filters by keyword', () {
      final filtered = EvidenceLedgerInspectFilter.apply(
        items: items,
        query: 'sleep',
        dateFilter: EvidenceLedgerDateFilter.all,
      );

      expect(filtered, hasLength(1));
      expect(filtered.first.id, 'weak');
    });

    test('filters by date window', () {
      final filtered = EvidenceLedgerInspectFilter.apply(
        items: items,
        query: '',
        dateFilter: EvidenceLedgerDateFilter.last30Days,
        now: DateTime(2026, 8, 10),
      );

      expect(filtered, hasLength(1));
      expect(filtered.first.id, 'strong');
    });
  });
}