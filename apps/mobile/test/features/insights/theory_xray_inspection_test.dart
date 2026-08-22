import 'package:archiveme_mobile/features/archive_theory/theory_ranking_engine.dart';
import 'package:archiveme_mobile/features/insights/theory_xray_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/archive_quality_personas.dart';

void main() {
  const engine = TheoryRankingEngine();

  test('attaches inspection metadata with scoring breakdown and chunks', () {
    final entries = buildPersonaArchive(
      ArchiveQualityPersona.relationshipFocused,
      count: 100,
    );
    final eligible =
        entries.where((e) => e.transcript.trim().length >= 24).toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final result = engine.rank(entries: entries, eligible: eligible);
    final primary = result.primaryTheory;
    expect(primary, isNotNull);

    final inspection = primary!.inspection;
    expect(inspection, isNotNull);
    expect(inspection!.finalConfidencePercent, primary.confidencePercent);
    expect(inspection.finalRankScore, primary.rankScore);
    expect(inspection.confidenceBreakdown.counterPenalty, isA<int>());
    expect(inspection.retrievedChunks, isNotEmpty);

    final supporting = inspection.retrievedChunks
        .where((chunk) => chunk.role == TheoryRetrievalRole.supporting)
        .toList();
    expect(supporting, isNotEmpty);
    for (final chunk in supporting) {
      expect(chunk.excerpt, isNotEmpty);
      expect(chunk.keywordOverlap, greaterThanOrEqualTo(2));
    }
  });
}
