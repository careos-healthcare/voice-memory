import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/proof_admission/archive_correction.dart';
import 'package:voicememory_mobile/features/proof_admission/archive_correction_migration.dart';

void main() {
  final seed = ArchiveCorrectionMigrationSeed(
    archiveScope: 'archive-1',
    targetProofId: 'proof-1',
    targetProofFingerprint: 'proof-fingerprint',
    semanticFramingFingerprint: 'semantic-fingerprint',
    wordingFingerprint: 'wording-fingerprint',
    affectedEvidenceRefs: const ['evidence-1'],
    createdAt: DateTime.utc(2026, 8, 1),
  );

  ArchiveCorrection? migrateArchive(Map<String, dynamic> json) =>
      ArchiveCorrectionMigration.fromArchiveFeedbackJson(json, seed: seed);

  ArchiveCorrection? migrateInsight(Map<String, dynamic> json) =>
      ArchiveCorrectionMigration.fromInsightFeedbackJson(json, seed: seed);

  ArchiveCorrection? migrateProofQuality(Map<String, dynamic> json) =>
      ArchiveCorrectionMigration.fromProofQualityJson(json, seed: seed);

  ArchiveCorrection? migrateSignal(Map<String, dynamic> json) =>
      ArchiveCorrectionMigration.fromSignalFeedbackJson(json, seed: seed);

  group('migration table v${ArchiveCorrectionMigration.migrationVersion}', () {
    test(
      'row 1: accurate, fits, feelsRight and useful become exactlyRight',
      () {
        final accurate = migrateArchive({'type': 'accurate'});
        final fits = migrateInsight({'choice': 'fits'});
        final feelsRight = migrateArchive({'type': 'feelsRight'});
        final useful = migrateProofQuality({'feedbackState': 'useful'});

        expect(accurate?.choice, ArchiveCorrectionChoice.exactlyRight);
        expect(fits?.choice, ArchiveCorrectionChoice.exactlyRight);
        expect(feelsRight?.choice, ArchiveCorrectionChoice.exactlyRight);
        expect(useful?.choice, ArchiveCorrectionChoice.exactlyRight);
        expect(accurate?.qualifier, isNull);
      },
    );

    test('row 2: wrongAngle and anotherAngle become wrong', () {
      final wrongAngle = migrateArchive({'type': 'wrongAngle'});
      final anotherAngle = migrateSignal({'action': 'anotherAngle'});

      expect(wrongAngle?.choice, ArchiveCorrectionChoice.wrong);
      expect(anotherAngle?.choice, ArchiveCorrectionChoice.wrong);
    });

    test('row 2: wording-only legacy evidence downgrades to wrongWording', () {
      final flagged = migrateArchive({
        'type': 'wrongAngle',
        'wordingOnly': true,
      });
      final scoped = migrateArchive({
        'type': 'wrongAngle',
        'rejectionScope': 'wording_only',
      });
      final reason = migrateSignal({
        'action': 'anotherAngle',
        'reason': 'wrongWording',
      });
      final renameOnly = migrateArchive({
        'type': 'wrongAngle',
        'correctionAction': 'renamePattern',
      });

      expect(flagged?.choice, ArchiveCorrectionChoice.wrongWording);
      expect(scoped?.choice, ArchiveCorrectionChoice.wrongWording);
      expect(reason?.choice, ArchiveCorrectionChoice.wrongWording);
      expect(renameOnly?.choice, ArchiveCorrectionChoice.wrongWording);
    });

    test(
      'row 3: tooGeneric and tooVague become wrongWording, scopeTooBroad',
      () {
        final tooGeneric = migrateArchive({'type': 'tooGeneric'});
        final tooVague = migrateProofQuality({'feedbackState': 'tooVague'});
        final snakeCase = migrateProofQuality({'feedbackState': 'too_vague'});

        expect(tooGeneric?.choice, ArchiveCorrectionChoice.wrongWording);
        expect(tooGeneric?.qualifier, ArchiveCorrectionQualifier.scopeTooBroad);
        expect(tooVague?.choice, ArchiveCorrectionChoice.wrongWording);
        expect(tooVague?.qualifier, ArchiveCorrectionQualifier.scopeTooBroad);
        expect(snakeCase?.qualifier, ArchiveCorrectionQualifier.scopeTooBroad);
      },
    );

    test('row 4: notQuite becomes partlyRight', () {
      final notQuite = migrateInsight({'choice': 'notQuite'});

      expect(notQuite?.choice, ArchiveCorrectionChoice.partlyRight);
      expect(notQuite?.qualifier, isNull);
    });

    test('row 4: notQuite with stronger rejection evidence becomes wrong', () {
      final removed = migrateInsight({'choice': 'notQuite', 'rejected': true});
      final escalated = migrateInsight({
        'choice': 'notQuite',
        'followUpChoice': 'notMe',
      });
      final repeated = migrateArchive({
        'type': 'notQuite',
        'rejectionCount':
            ArchiveCorrectionMigration.strongerRejectionRepeatThreshold,
      });

      expect(removed?.choice, ArchiveCorrectionChoice.wrong);
      expect(escalated?.choice, ArchiveCorrectionChoice.wrong);
      expect(repeated?.choice, ArchiveCorrectionChoice.wrong);
    });

    test('row 5: tooEarly becomes partlyRight with the tooEarly qualifier', () {
      final tooEarly = migrateInsight({'choice': 'tooEarly'});

      expect(tooEarly?.choice, ArchiveCorrectionChoice.partlyRight);
      expect(tooEarly?.qualifier, ArchiveCorrectionQualifier.tooEarly);
    });

    test('row 6: legacy Hide suppresses the exact artifact as wrong', () {
      final hide = migrateArchive({'type': 'Hide'});
      final hidden = migrateArchive({'type': 'hidden'});
      final hideThis = migrateArchive({'type': 'hide this'});

      for (final migrated in [hide, hidden, hideThis]) {
        expect(migrated?.choice, ArchiveCorrectionChoice.wrong);
        expect(migrated?.targetProofId, seed.targetProofId);
        expect(migrated?.archiveScope, seed.archiveScope);
      }
    });

    test('row 6: legacy Hide never escalates to ignoreForever', () {
      const hideValues = ['Hide', 'hide', 'hidden', 'hide this', 'hide_this'];
      final systems = LegacyFeedbackSystem.values;

      for (final value in hideValues) {
        for (final system in systems) {
          final migrated = ArchiveCorrectionMigration.migrate(
            system: system,
            json: {
              'type': value,
              'choice': value,
              'action': value,
              'feedbackState': value,
            },
            seed: seed,
          );
          expect(
            migrated?.choice,
            isNot(ArchiveCorrectionChoice.ignoreForever),
            reason:
                '$value from ${system.sourceSurface} must stay '
                'artifact-scoped',
          );
        }
      }
    });

    test(
      'row 7: notRelated and wrongThread become wrongEvidence, not wrong',
      () {
        final notRelated = migrateSignal({'action': 'notRelated'});
        final wrongThread = migrateSignal({'action': 'wrongThread'});
        final notRelevant = migrateProofQuality({
          'feedbackState': 'notRelevant',
        });

        expect(notRelated?.choice, ArchiveCorrectionChoice.wrongEvidence);
        expect(wrongThread?.choice, ArchiveCorrectionChoice.wrongEvidence);
        expect(notRelevant?.choice, ArchiveCorrectionChoice.wrongEvidence);
        expect(notRelated?.choice, isNot(ArchiveCorrectionChoice.wrong));
      },
    );

    test('row 8: notMe becomes wrong', () {
      final notMe = migrateArchive({'type': 'notMe'});

      expect(notMe?.choice, ArchiveCorrectionChoice.wrong);
    });

    test('row 9: notUseful becomes partlyRight', () {
      final notUseful = migrateSignal({'action': 'notUseful'});

      expect(notUseful?.choice, ArchiveCorrectionChoice.partlyRight);
    });

    test('row 10: deferral signals are not corrections at all', () {
      final watchTheme = migrateInsight({'choice': 'saveAsWatchTheme'});
      final background = migrateSignal({'action': 'background'});
      final watchLightly = migrateSignal({'action': 'watchLightly'});

      expect(watchTheme, isNull);
      expect(background, isNull);
      expect(watchLightly, isNull);
      expect(
        ArchiveCorrectionMigration.isDeferralSignal('watchLightly'),
        isTrue,
      );
      expect(
        ArchiveCorrectionMigration.recognisesLegacyValue('saveAsWatchTheme'),
        isTrue,
      );
    });

    test('every migrated correction names its legacy source system', () {
      expect(
        migrateArchive({'type': 'notMe'})?.sourceSurface,
        'legacy_archive_feedback',
      );
      expect(
        migrateInsight({'choice': 'fits'})?.sourceSurface,
        'legacy_insight_feedback',
      );
      expect(
        migrateProofQuality({'feedbackState': 'useful'})?.sourceSurface,
        'legacy_proof_quality',
      );
      expect(
        migrateSignal({'action': 'notUseful'})?.sourceSurface,
        'legacy_signal_feedback',
      );
    });
  });

  group('migration safety', () {
    test('idempotent migration produces identical ids and no duplicates', () {
      final legacy = <String, dynamic>{
        'id': 'legacy-row-9',
        'type': 'tooGeneric',
        'createdAt': '2026-07-02T09:15:00.000Z',
      };

      final first = migrateArchive(legacy)!;
      final second = migrateArchive(Map<String, dynamic>.of(legacy))!;

      expect(second.correctionId, first.correctionId);
      expect(second.toJson(), first.toJson());

      final record = LegacyFeedbackRecord(
        system: LegacyFeedbackSystem.archiveFeedback,
        json: legacy,
        seed: seed,
      );
      final batch = ArchiveCorrectionMigration.migrateAll([record, record]);
      expect(batch, hasLength(1));
      expect(batch.single.correctionId, first.correctionId);

      final rerun = ArchiveCorrectionMigration.migrateAll(
        [record],
        existingCorrections: [first],
      );
      expect(rerun, isEmpty);

      expect(
        ArchiveCorrectionMigration.isAlreadyMigrated(
          existingCorrections: [first],
          system: LegacyFeedbackSystem.archiveFeedback,
          json: legacy,
          seed: seed,
        ),
        isTrue,
      );
      expect(
        ArchiveCorrectionMigration.isAlreadyMigrated(
          existingCorrections: [first],
          system: LegacyFeedbackSystem.archiveFeedback,
          json: {...legacy, 'id': 'legacy-row-10'},
          seed: seed,
        ),
        isFalse,
      );
    });

    test('distinct legacy systems never collide on one correction id', () {
      final legacy = <String, dynamic>{
        'id': 'legacy-row-9',
        'type': 'useful',
        'choice': 'useful',
        'feedbackState': 'useful',
        'action': 'useful',
      };
      final ids = LegacyFeedbackSystem.values
          .map(
            (system) => ArchiveCorrectionMigration.correctionIdFor(
              system: system,
              json: legacy,
              seed: seed,
            ),
          )
          .toSet();

      expect(ids, hasLength(LegacyFeedbackSystem.values.length));
    });

    test('legacy free text never survives migration', () {
      const freeText = [
        'they said the pattern was about my sister',
        'quoted transcript line',
        'Evenings after work',
        'Signal: rushing again',
        'private reviewer note',
      ];
      final migrated = migrateArchive({
        'id': 'legacy-row-11',
        'type': 'tooGeneric',
        'correctionNotes': freeText[0],
        'quote': freeText[1],
        'patternTitle': freeText[2],
        'signalTitle': freeText[3],
        'note': freeText[4],
      })!;

      final encoded = jsonEncode(migrated.toJson());
      for (final text in freeText) {
        expect(encoded, isNot(contains(text)));
      }
      expect(migrated.choice, ArchiveCorrectionChoice.wrongWording);
    });

    test('unknown legacy values return null instead of guessing', () {
      expect(migrateArchive({'type': 'somethingNew'}), isNull);
      expect(migrateInsight({'choice': ''}), isNull);
      expect(migrateProofQuality({'feedbackState': 42}), isNull);
      expect(migrateSignal(const {}), isNull);
      expect(
        ArchiveCorrectionMigration.recognisesLegacyValue('somethingNew'),
        isFalse,
      );
    });

    test('uses safe seed fields and the legacy timestamp', () {
      final migrated = migrateProofQuality({
        'feedbackState': 'useful',
        'answeredAt': '2026-08-03T12:30:00.000Z',
        'privateNotes': 'do not migrate',
      })!;

      expect(migrated.archiveScope, seed.archiveScope);
      expect(migrated.targetProofFingerprint, seed.targetProofFingerprint);
      expect(migrated.affectedEvidenceRefs, seed.affectedEvidenceRefs);
      expect(migrated.createdAt, DateTime.utc(2026, 8, 3, 12, 30));
      expect(migrated.updatedAt, migrated.createdAt);
      expect(migrated.superseded, isFalse);
      expect(jsonEncode(migrated.toJson()), isNot(contains('do not migrate')));
    });

    test('migration leaves the legacy record untouched', () {
      final legacy = <String, dynamic>{
        'id': 'legacy-row-12',
        'type': 'notMe',
        'patternTitle': 'Late night spirals',
      };
      final snapshot = Map<String, dynamic>.of(legacy);

      migrateArchive(legacy);

      expect(legacy, snapshot);
    });
  });
}
