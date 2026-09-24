import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:uuid/uuid.dart';

/// Schedules sqlite-vec indexing and a short summary for a finished call.
typedef VoiceInsightIndexer =
    Future<void> Function(JournalEntry entry, List<String> lifePatterns);

/// Optional embedding hook. The app can point this at the sqlite-vec worker.
abstract final class VoiceInsightHooks {
  static VoiceInsightIndexer? index;
}

/// Turns a finished call into a journal entry with Life Patterns.
class VoiceJournalPipeline {
  VoiceJournalPipeline({
    this.save,
    this.index,
    DateTime Function()? clock,
    String Function()? idFactory,
  }) : _clock = clock ?? DateTime.now,
       _idFactory = idFactory ?? const Uuid().v4;

  final Future<void> Function(JournalEntry entry)? save;
  final VoiceInsightIndexer? index;
  final DateTime Function() _clock;
  final String Function() _idFactory;

  Future<VoiceJournalResult> complete(String transcript) async {
    final text = transcript.trim();
    final patterns = extractLifePatterns(text);
    final summary = patterns.isEmpty ? text : patterns.first;
    final entry = JournalEntry(
      id: _idFactory(),
      createdAt: _clock().toUtc(),
      transcript: text,
      durationSeconds: 0,
      reflection: Reflection(
        mood: 'reflective',
        emotionalIntensity: 1,
        recurringThemes: patterns,
        exactLanguagePattern: summary,
        concreteObservation: summary,
        repeatedSignal: patterns.length > 1 ? patterns[1] : summary,
      ),
      captureSource: 'voice_call',
    );
    await save?.call(entry);
    await index?.call(entry, patterns);
    return VoiceJournalResult(entry: entry, lifePatterns: patterns);
  }
}

class VoiceJournalResult {
  const VoiceJournalResult({required this.entry, required this.lifePatterns});

  final JournalEntry entry;
  final List<String> lifePatterns;
}

/// Pulls up to three distinct sentences to show as Life Patterns.
List<String> extractLifePatterns(String transcript) {
  final cleaned = transcript.trim();
  if (cleaned.isEmpty) return const [];
  final pieces = cleaned.split(RegExp(r'[.!?\n]+'));
  final patterns = <String>[];
  for (final piece in pieces) {
    final line = piece.trim();
    if (line.length < 8) continue;
    if (patterns.contains(line)) continue;
    patterns.add(line);
    if (patterns.length == 3) break;
  }
  if (patterns.isEmpty) {
    final clipped = cleaned.length > 80 ? cleaned.substring(0, 80) : cleaned;
    return [clipped];
  }
  return patterns;
}
