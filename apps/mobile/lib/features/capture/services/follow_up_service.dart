import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/core/database/database_provider.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/app_services.dart';

/// A follow-up that cites one older entry next to what was just saved.
class FollowUpReflection {
  const FollowUpReflection({
    required this.pastEntryId,
    required this.prompt,
    required this.citation,
    required this.question,
  });

  final String pastEntryId;
  final String prompt;
  final String citation;
  final String question;
}

const followUpQuestion = 'What has changed or evolved since then?';

/// Prompt sent when a model is asked for one gentle question.
String followUpPrompt({
  required String pastDate,
  required String pastSnippet,
  required String currentTranscript,
}) {
  return "On $pastDate the user said: '$pastSnippet'. "
      "Today they said: '$currentTranscript'. "
      'Ask a single, gentle question about what has changed or evolved.';
}

/// The quotes shown above the question.
String followUpCitation({
  required String pastDate,
  required String pastSnippet,
  required String currentSnippet,
}) {
  return 'On $pastDate you said "$pastSnippet". '
      'Today you said "$currentSnippet".';
}

String formatFollowUpDate(DateTime value) {
  final local = value.toLocal();
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${local.day} ${months[local.month - 1]} ${local.year}';
}

/// Builds a cited follow-up from the local journal. Stays quiet while
/// [AppFlags.postSaveFollowUp] is off.
class FollowUpService {
  FollowUpService({
    Future<List<double>?> Function(String entryId)? readEmbedding,
    Future<List<SimilarEntry>> Function(
      List<double> vector, {
      int excludeWithinDays,
      int limit,
    })?
    findSimilar,
  }) : _readEmbedding = readEmbedding ?? _readStoredEmbedding,
       _findSimilar = findSimilar ?? _findOlderMatch;

  final Future<List<double>?> Function(String entryId) _readEmbedding;
  final Future<List<SimilarEntry>> Function(
    List<double> vector, {
    int excludeWithinDays,
    int limit,
  })
  _findSimilar;

  Future<FollowUpReflection?> forEntry(
    JournalEntry entry, {
    bool? enabled,
  }) async {
    if (!(enabled ?? AppFlags.postSaveFollowUp)) return null;
    final current = entry.transcript.trim();
    if (current.isEmpty) return null;

    final vector = await _readEmbedding(entry.id);
    if (vector == null) return null;
    final matches = await _findSimilar(
      vector,
      excludeWithinDays: 7,
      limit: 1,
    );
    if (matches.isEmpty) return null;

    final past = matches.first;
    final pastSnippet = shortVerbatimQuote(past.transcript);
    final pastDate = formatFollowUpDate(past.createdAt);
    if (pastSnippet.isEmpty) return null;
    return FollowUpReflection(
      pastEntryId: past.id,
      prompt: followUpPrompt(
        pastDate: pastDate,
        pastSnippet: pastSnippet,
        currentTranscript: current,
      ),
      citation: followUpCitation(
        pastDate: pastDate,
        pastSnippet: pastSnippet,
        currentSnippet: shortVerbatimQuote(current),
      ),
      question: followUpQuestion,
    );
  }

  static Future<List<double>?> _readStoredEmbedding(String entryId) {
    if (!AppServices.isInitialized) return Future.value();
    return DatabaseProvider(
      AppServices.instance.sqliteDatabase.database,
    ).readEmbedding(entryId);
  }

  static Future<List<SimilarEntry>> _findOlderMatch(
    List<double> vector, {
    int excludeWithinDays = 7,
    int limit = 1,
  }) {
    if (!AppServices.isInitialized) return Future.value(const []);
    return DatabaseProvider(
      AppServices.instance.sqliteDatabase.database,
    ).findSimilarEntries(
      vector,
      excludeWithinDays: excludeWithinDays,
      limit: limit,
    );
  }
}
