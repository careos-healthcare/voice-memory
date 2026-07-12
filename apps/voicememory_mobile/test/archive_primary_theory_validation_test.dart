import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_analyst/archive_analyst_engine.dart';
import 'package:voicememory_mobile/features/archive_deep_dive/archive_deep_dive_engine.dart';
import 'package:voicememory_mobile/features/archive_synthesis/archive_synthesis_pack_builder.dart';
import 'package:voicememory_mobile/features/archive_v1/archive_v1_builder.dart';
import 'package:voicememory_mobile/features/belief_evolution/belief_evolution_service.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

import 'support/archive_quality_personas.dart';

void main() {
  test(
    'unified primary theory — all surfaces agree',
    () async {
    final failures = <String>[];

    for (final persona in ArchiveQualityPersona.values) {
      for (final size in [50, 100, 200]) {
        final dir = await Directory.systemTemp.createTemp(
          'primary_${persona.name}_$size',
        );
        final prefs = await MobilePrefsStore.open('${dir.path}/prefs.json');
        final evolution = BeliefEvolutionService.fromPrefs(prefs);
        final entries = buildPersonaArchive(persona, count: size);

        final v1 = await const ArchiveV1Builder().build(
          entries: entries,
          evolutionService: evolution,
        );
        final dive = const ArchiveDeepDiveEngine().build(v1: v1);
        final analyst = await const ArchiveAnalystEngine().build(
          entries: entries,
          evolutionService: evolution,
        );

        final theoryStmt = v1.theory?.statement.trim();
        final rankingPrimary = v1.theoryRanking?.primaryStatement?.trim();
        final analystPrimary = analyst.currentBeliefs
            .where((b) => b.isPrimary)
            .map((b) => b.statement.trim())
            .firstOrNull;

        final label = '${persona.name}@$size';

        if (theoryStmt == null || theoryStmt.isEmpty) {
          if (persona == ArchiveQualityPersona.relationshipFocused) {
            failures.add('$label: missing theory for relationship persona');
          }
          continue;
        }

        if (rankingPrimary != theoryStmt) {
          failures.add('$label: theory != theoryRanking.primary');
        }
        if (analystPrimary != theoryStmt) {
          failures.add('$label: theory != analyst primary');
        }
        if (dive != null && dive.beliefStatement.trim() != theoryStmt) {
          failures.add('$label: deep dive != theory');
        }
        if (v1.lifecycle.current?.statement.trim() != theoryStmt) {
          failures.add('$label: lifecycle current != theory');
        }

        final ev = v1.theory!.evidenceCount;
        final conf = v1.theory!.confidencePercent;
        if (ev < 3) {
          failures.add('$label: hero evidence $ev < 3');
        }
        if (conf < 15) {
          failures.add('$label: hero confidence $conf% < 15%');
        }

        if (persona == ArchiveQualityPersona.relationshipFocused) {
          final lower = theoryStmt.toLowerCase();
          if (!lower.contains('partner') && !lower.contains('relationship')) {
            failures.add(
              '$label: relationship hero not relationship-themed: $theoryStmt',
            );
          }
          if (lower.contains('work delivery pressure dominates')) {
            failures.add('$label: work-delivery hero on relationship persona');
          }
        }

        final pack = ArchiveSynthesisPackBuilder.build(
          view: v1,
          monthKey: '2026-05',
          milestonesReached: const {},
        );
        final packTheory = (pack['theory'] as Map?)?['statement'] as String?;
        if (packTheory?.trim() != theoryStmt) {
          failures.add('$label: GPT-5 pack theory != hero');
        }
      }
    }

    expect(
      failures,
      isEmpty,
      reason: 'Unified primary theory failures:\n${failures.join('\n')}',
    );
  }, timeout: const Timeout(Duration(minutes: 3)));
}
