import 'package:archiveme_mobile/features/archive_surprises/archive_surprises_engine.dart';
import 'package:archiveme_mobile/features/archive_surprises/archive_surprises_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/archive_quality_personas.dart';

void main() {
  const engine = ArchiveSurprisesEngine();

  test('relationship-focused @100 surfaces career vs relationships gap', () {
    final entries = buildPersonaArchive(
      ArchiveQualityPersona.relationshipFocused,
      count: 100,
    );
    final view = engine.build(entries: entries);
    expect(view.hasObservations, isTrue);
    // Work-noise vs relationship-importance arc: dominance gap, stated gap, or theme cessation.
    expect(
      view.observations.any(
        (o) =>
            o.kind == ArchiveSurpriseKind.themeDominanceGap ||
            o.kind == ArchiveSurpriseKind.statedImportanceGap ||
            o.kind == ArchiveSurpriseKind.themeStoppedMentioning,
      ),
      isTrue,
      reason: view.observations.map((o) => o.observation).join('\n'),
    );
    for (final o in view.observations) {
      expect(o.evidenceEntryIds.length, greaterThanOrEqualTo(3));
    }
  });

  test('burned-out employee @100 has evidence-backed surprises', () {
    final entries = buildPersonaArchive(
      ArchiveQualityPersona.burnedOutEmployee,
      count: 100,
    );
    final view = engine.build(entries: entries);
    expect(view.hasObservations, isTrue);
    expect(view.observations.first.evidenceCount, greaterThanOrEqualTo(3));
  });

  test('founder @200 may surface dominance or cessation not generic copy', () {
    final entries = buildPersonaArchive(
      ArchiveQualityPersona.founder,
      count: 200,
    );
    final view = engine.build(entries: entries);
    expect(view.hasObservations, isTrue);
    for (final o in view.observations) {
      expect(o.observation.toLowerCase(), isNot(contains('you focus on')));
      expect(
        o.observation.toLowerCase(),
        isNot(contains('you may keep returning')),
      );
    }
  });

  test('fitness-focused @100 avoids empty generic surprises', () {
    final entries = buildPersonaArchive(
      ArchiveQualityPersona.fitnessFocused,
      count: 100,
    );
    final view = engine.build(entries: entries);
    if (view.hasObservations) {
      for (final o in view.observations) {
        expect(o.observation, isNot(contains('You focus on')));
        expect(o.evidenceEntryIds, isNotEmpty);
      }
    } else {
      expect(view.emptyMessage, isNotNull);
    }
  });

  test('anxious overthinker @100 observations are evidence-backed', () {
    final entries = buildPersonaArchive(
      ArchiveQualityPersona.anxiousOverthinker,
      count: 100,
    );
    final view = engine.build(entries: entries);
    if (!view.hasObservations) return;
    for (final o in view.observations) {
      expect(o.evidenceCount, greaterThanOrEqualTo(3));
      expect(o.observation.length, greaterThan(24));
    }
  });
}