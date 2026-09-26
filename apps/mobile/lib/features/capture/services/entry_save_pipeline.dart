import 'package:archiveme_mobile/models/app_spoken_question.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

enum VoiceChatRole { user, app }

/// One live bubble. Partial user lines are shown while speaking and left out
/// of the saved entry.
class VoiceChatLine {
  const VoiceChatLine({
    required this.role,
    required this.text,
    required this.at,
    this.partial = false,
  });

  final VoiceChatRole role;
  final String text;
  final DateTime at;
  final bool partial;

  bool get isUser => role == VoiceChatRole.user;
}

/// Turns a conversation into one journal entry.
///
/// [JournalEntry.transcript] is only the person's words. The app's questions
/// are stored beside it, with the time they were asked.
class EntrySavePipeline {
  const EntrySavePipeline._();

  static JournalEntry consolidate({
    required JournalEntry entry,
    required List<VoiceChatLine> lines,
  }) {
    final userParts = <String>[];
    final questions = <AppSpokenQuestion>[];
    var userChars = 0;
    for (final line in lines) {
      final text = line.text.trim();
      if (text.isEmpty || line.partial) continue;
      if (line.isUser) {
        if (userParts.isNotEmpty) userChars += 1;
        userParts.add(text);
        userChars += text.length;
        continue;
      }
      questions.add(
        AppSpokenQuestion(
          text: text,
          askedAt: line.at.toUtc(),
          afterUserChars: userChars,
        ),
      );
    }
    return entry.copyWith(
      transcript: userParts.join(' '),
      display: entry.display.copyWith(aiQuestions: questions),
    );
  }
}

/// User words and app questions in the order they were spoken.
List<VoiceChatLine> savedConversationLines({
  required String transcript,
  required List<AppSpokenQuestion> questions,
}) {
  final sorted = [...questions]..sort((a, b) {
    final byPlace = a.afterUserChars.compareTo(b.afterUserChars);
    if (byPlace != 0) return byPlace;
    return a.askedAt.compareTo(b.askedAt);
  });
  final lines = <VoiceChatLine>[];
  var cursor = 0;
  final words = transcript;
  for (final question in sorted) {
    final cut = question.afterUserChars.clamp(cursor, words.length);
    final user = words.substring(cursor, cut).trim();
    if (user.isNotEmpty) {
      lines.add(
        VoiceChatLine(
          role: VoiceChatRole.user,
          text: user,
          at: question.askedAt,
        ),
      );
    }
    lines.add(
      VoiceChatLine(
        role: VoiceChatRole.app,
        text: question.text,
        at: question.askedAt,
      ),
    );
    cursor = cut;
  }
  final rest = words.substring(cursor.clamp(0, words.length)).trim();
  if (rest.isNotEmpty) {
    lines.add(
      VoiceChatLine(
        role: VoiceChatRole.user,
        text: rest,
        at: sorted.isEmpty ? DateTime.now().toUtc() : sorted.last.askedAt,
      ),
    );
  } else if (lines.isEmpty && words.trim().isNotEmpty) {
    lines.add(
      VoiceChatLine(
        role: VoiceChatRole.user,
        text: words.trim(),
        at: DateTime.now().toUtc(),
      ),
    );
  }
  return lines;
}
