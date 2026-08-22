import 'package:archiveme_mobile/features/pressure_retention/pressure_check_in_option.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_context.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';

/// Turns a one-tap pressure selection (plus optional context) into an
/// evidence-grade journal entry and a structured pressure record.
///
/// Pure / no IO — safe to use directly in tests.
class PressureCheckInEngine {
  const PressureCheckInEngine();

  /// Builds the first-person transcript stored on the journal entry.
  ///
  /// The selected option alone produces a complete, evidence-grade sentence so
  /// a check-in can be saved with no typing at all.
  String buildTranscript({
    required PressureCheckInOption option,
    List<PressureContext> contexts = const [],
    String? fear,
    String? stopCostNote,
    bool choseToStop = false,
  }) {
    final parts = <String>[option.momentPhrase];

    if (contexts.isNotEmpty) {
      final labels = contexts.map((c) => c.label.toLowerCase()).join(', ');
      parts.add('This came up around $labels.');
    }

    final fearText = fear?.trim();
    if (fearText != null && fearText.isNotEmpty) {
      parts.add('What I feared if I stopped: $fearText');
    }

    final note = stopCostNote?.trim();
    if (note != null && note.isNotEmpty) {
      parts.add(note);
    }

    if (choseToStop) {
      parts.add('This time I chose to stop instead of doing more.');
    }

    return parts.join(' ');
  }

  /// Builds the journal entry + pressure record for a check-in.
  PressureCheckInBuildResult build({
    required String entryId,
    required PressureCheckInOption option,
    required DateTime now,
    List<PressureContext> contexts = const [],
    String? fear,
    String? stopCostNote,
    bool choseToStop = false,
  }) {
    final transcript = buildTranscript(
      option: option,
      contexts: contexts,
      fear: fear,
      stopCostNote: stopCostNote,
      choseToStop: choseToStop,
    );

    final entry = JournalEntry(
      id: entryId,
      createdAt: now,
      transcript: transcript,
      durationSeconds: 0,
      reflection: Reflection(
        mood: 'pressure',
        emotionalIntensity: 3,
        recurringThemes: contexts.map((c) => c.label).toList(),
        exactLanguagePattern: option.label,
        concreteObservation: transcript,
        repeatedSignal: option.id,
      ),
    );

    final record = PressureCheckInRecord(
      entryId: entryId,
      createdAt: now,
      optionId: option.id,
      contextIds: contexts.map((c) => c.id).toList(),
      fear: _trimToNull(fear),
      stopCostNote: _trimToNull(stopCostNote),
      choseToStop: choseToStop,
      transcript: transcript,
    );

    return PressureCheckInBuildResult(entry: entry, record: record);
  }

  static String? _trimToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}

class PressureCheckInBuildResult {
  const PressureCheckInBuildResult({required this.entry, required this.record});

  final JournalEntry entry;
  final PressureCheckInRecord record;
}