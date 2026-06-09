import 'pattern_memory_model.dart';
import 'pattern_next_action_model.dart';
import 'pattern_progress_model.dart';
import 'pattern_share_recap_model.dart';
import 'weekly_pattern_recap_model.dart';

/// Turns the current pattern story into a simple, keepable text recap.
class PatternShareRecapEngine {
  const PatternShareRecapEngine();

  static const String _signature = 'Made with ArchiveMe';
  static const String _fallbackQuestion = 'Did this show up again?';

  PatternShareRecap build({
    PatternMemory? memory,
    PatternProgressMoment? progress,
    PatternNextAction? action,
    WeeklyPatternRecap? weekly,
  }) {
    final createdAt = weekly?.createdAt ??
        progress?.createdAt ??
        action?.createdAt ??
        memory?.updatedAt ??
        DateTime.now();

    if (weekly != null && weekly.shouldShow) {
      return _weekly(weekly, createdAt);
    }
    if (progress != null && progress.shouldShow) {
      return _progress(progress, createdAt);
    }
    if (memory != null && memory.checkInCount >= 2) {
      return _memory(memory, createdAt);
    }
    return _fallback(createdAt);
  }

  PatternShareRecap _weekly(WeeklyPatternRecap weekly, DateTime createdAt) {
    final lines = <String>[
      weekly.body,
      if (weekly.usefulLine != null && weekly.usefulLine!.isNotEmpty)
        weekly.usefulLine!,
      if (weekly.nextQuestion != null && weekly.nextQuestion!.isNotEmpty)
        'Next check: ${weekly.nextQuestion}',
    ];
    return _assemble(
      type: PatternShareRecapType.weekly,
      title: 'This week\u2019s pattern',
      body: weekly.headline,
      lines: lines,
      nextQuestion: weekly.nextQuestion,
      createdAt: createdAt,
    );
  }

  PatternShareRecap _progress(
    PatternProgressMoment progress,
    DateTime createdAt,
  ) {
    final lines = <String>[
      progress.body,
      if (progress.beforeLine != null && progress.beforeLine!.isNotEmpty)
        progress.beforeLine!,
      if (progress.helpedLine != null && progress.helpedLine!.isNotEmpty)
        progress.helpedLine!,
      'Next check: ${progress.nextLine}',
    ];
    return _assemble(
      type: PatternShareRecapType.progress,
      title: 'Pattern progress',
      body: progress.headline,
      lines: lines,
      nextQuestion: progress.nextLine,
      createdAt: createdAt,
    );
  }

  PatternShareRecap _memory(PatternMemory memory, DateTime createdAt) {
    final hasNext = memory.nextBestQuestion != null &&
        memory.nextBestQuestion!.trim().isNotEmpty;
    final lines = <String>[
      'Showed up again: ${memory.showedAgainCount}',
      'Felt lighter: ${memory.lighterCount}',
      'Felt heavier: ${memory.heavierCount}',
      if (hasNext) 'Next check: ${memory.nextBestQuestion}',
    ];
    return _assemble(
      type: PatternShareRecapType.memory,
      title: 'Pattern memory',
      body: 'You checked this pattern ${memory.checkInCount} times.',
      lines: lines,
      nextQuestion: hasNext ? memory.nextBestQuestion : null,
      createdAt: createdAt,
    );
  }

  PatternShareRecap _fallback(DateTime createdAt) {
    return _assemble(
      type: PatternShareRecapType.fallback,
      title: 'My pattern',
      body: 'I am starting to notice a pattern.',
      lines: const ['Next check: $_fallbackQuestion'],
      nextQuestion: _fallbackQuestion,
      createdAt: createdAt,
    );
  }

  PatternShareRecap _assemble({
    required PatternShareRecapType type,
    required String title,
    required String body,
    required List<String> lines,
    required String? nextQuestion,
    required DateTime createdAt,
  }) {
    final cleanLines =
        lines.map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    return PatternShareRecap(
      id: 'share_${type.id}_${createdAt.microsecondsSinceEpoch}',
      createdAt: createdAt,
      type: type,
      title: title,
      body: body,
      lines: cleanLines,
      nextQuestion: nextQuestion,
      plainText: _plainText(title, body, cleanLines),
    );
  }

  String _plainText(String title, String body, List<String> lines) {
    final buffer = StringBuffer()
      ..writeln(title)
      ..writeln()
      ..writeln(body);
    if (lines.isNotEmpty) {
      buffer.writeln();
      for (final line in lines) {
        buffer.writeln('- $line');
      }
    }
    buffer
      ..writeln()
      ..write(_signature);
    return buffer.toString();
  }
}
