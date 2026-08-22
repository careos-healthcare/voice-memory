import 'package:archiveme_mobile/features/clinical_sandbox/data/clinical_data_governance.dart';
import 'package:archiveme_mobile/features/curiosity_loop/domain/models/cognitive_biomarkers.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:flutter_test/flutter_test.dart';

JournalEntry _entryWithBiomarkers() {
  return JournalEntry(
    id: 'e1',
    createdAt: DateTime.utc(2026, 8),
    transcript: 'sample transcript',
    durationSeconds: 10,
    reflection: const Reflection(
      mood: '',
      emotionalIntensity: 0,
      recurringThemes: [],
      exactLanguagePattern: '',
      concreteObservation: '',
      repeatedSignal: '',
    ),
    biomarkers: const CognitiveBiomarkers(
      lexicalDiversity: 0.4,
      cohesionDrift: 0.2,
      emotionalVolatility: 0.1,
    ),
    wasGrounded: true,
    parentHookId: 'hook-1',
  );
}

void main() {
  group('ClinicalDataGovernance', () {
    test('strips clinical fields from outbound journal entries', () {
      final sanitized =
          ClinicalDataGovernance.sanitizeEntryForOutboundSync(_entryWithBiomarkers());

      expect(sanitized.biomarkers, isNull);
      expect(sanitized.wasGrounded, isFalse);
      expect(sanitized.parentHookId, isNull);
    });

    test('redacts clinical telemetry metadata keys', () {
      final redacted = ClinicalDataGovernance.redactTelemetryMeta({
        'entry_id': 'e1',
        'lexical_diversity': 0.4,
        'observation_count': 2,
      });

      expect(redacted.containsKey('lexical_diversity'), isFalse);
      expect(redacted['entry_id'], 'e1');
      expect(redacted['observation_count'], 2);
    });
  });
}