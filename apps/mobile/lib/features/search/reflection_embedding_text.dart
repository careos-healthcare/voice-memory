import 'package:archiveme_mobile/api/models/capture_dto.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';

/// Canonical text fed to the reflection embedding encoder.
abstract final class ReflectionEmbeddingText {
  ReflectionEmbeddingText._();

  static String fromReflection(Reflection reflection) {
    return _join([
      reflection.mood,
      reflection.exactLanguagePattern,
      reflection.concreteObservation,
      reflection.repeatedSignal,
      reflection.tensionOrContradiction,
      reflection.avoidedOrVagueArea,
      reflection.nextSmallAction,
      ...reflection.recurringThemes,
      ...reflection.patternObservations,
    ]);
  }

  static String fromReflectionDto(ReflectionDto reflection) {
    return _join([
      reflection.mood,
      reflection.exactLanguagePattern,
      reflection.concreteObservation,
      reflection.repeatedSignal,
      reflection.tensionOrContradiction,
      reflection.avoidedOrVagueArea,
      reflection.nextSmallAction,
      ...reflection.recurringThemes,
      ...reflection.patternObservations,
    ]);
  }

  static String fromEntry(JournalEntry entry) {
    final reflectionText = fromReflection(entry.reflection);
    if (reflectionText.isNotEmpty) return reflectionText;
    return entry.transcript.trim();
  }

  static String _join(Iterable<String?> parts) {
    return parts
        .map((part) => part?.trim() ?? '')
        .where((part) => part.isNotEmpty)
        .join('\n');
  }
}
