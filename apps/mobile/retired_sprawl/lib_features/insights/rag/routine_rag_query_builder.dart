import 'package:archiveme_mobile/features/insights/rag/routine_rag_models.dart';
import 'package:archiveme_mobile/features/theme_tracking/theme_tracker_service.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Builds retrieval queries from the user's current emotional state.
abstract final class RoutineRagQueryBuilder {
  RoutineRagQueryBuilder._();

  static RoutineRagQuery fromLatestEntry({
    required JournalRoutineKind routine,
    required JournalEntry? latestEntry,
    int maxChunks = 6,
  }) {
    if (latestEntry == null) {
      return RoutineRagQuery(
        routine: routine,
        semanticQuery: _defaultSemanticQuery(routine),
        maxChunks: maxChunks,
      );
    }

    final reflection = latestEntry.reflection;
    final themes = {
      ...ThemeTrackerService.themesForEntry(latestEntry),
      ...reflection.recurringThemes.map((theme) => theme.trim().toLowerCase()),
    }.where((theme) => theme.isNotEmpty).toList(growable: false);

    return RoutineRagQuery(
      routine: routine,
      currentMood: reflection.mood,
      recurringThemes: themes,
      emotionalIntensity: reflection.emotionalIntensity,
      semanticQuery: _semanticQuery(
        routine: routine,
        mood: reflection.mood,
        themes: themes,
        tension: reflection.tensionOrContradiction,
      ),
      maxChunks: maxChunks,
    );
  }

  static RoutineRagQuery fromState({
    required JournalRoutineKind routine,
    String? currentMood,
    List<String> recurringThemes = const [],
    int? emotionalIntensity,
    int maxChunks = 6,
  }) {
    final themes = recurringThemes
        .map((theme) => theme.trim().toLowerCase())
        .where((theme) => theme.isNotEmpty)
        .toList(growable: false);

    return RoutineRagQuery(
      routine: routine,
      currentMood: currentMood,
      recurringThemes: themes,
      emotionalIntensity: emotionalIntensity,
      semanticQuery: _semanticQuery(
        routine: routine,
        mood: currentMood,
        themes: themes,
      ),
      maxChunks: maxChunks,
    );
  }

  static String _defaultSemanticQuery(JournalRoutineKind routine) {
    return switch (routine) {
      JournalRoutineKind.morning => 'morning intention focus energy today',
      JournalRoutineKind.evening =>
        'evening reflection tension unresolved rest boundaries',
    };
  }

  static String _semanticQuery({
    required JournalRoutineKind routine,
    String? mood,
    List<String> themes = const [],
    String? tension,
  }) {
    final parts = <String>[
      _defaultSemanticQuery(routine),
      if (mood != null && mood.trim().isNotEmpty) mood.trim(),
      ...themes,
      if (tension != null && tension.trim().isNotEmpty) tension.trim(),
    ];
    return parts.join(' ');
  }
}
