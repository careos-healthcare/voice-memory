import 'archive_reflection_model.dart';
import 'pressure_context.dart';
import 'pressure_check_in_record.dart';

/// A focused, evidence-based reflection helper — NOT a general chatbot.
///
/// It answers only four fixed questions, and only from local saved data. When
/// the archive lacks enough evidence it says so rather than guessing.
class ArchiveReflectionEngine {
  const ArchiveReflectionEngine();

  static const insufficientEvidence =
      'Your archive needs more evidence before saying that confidently.';

  static const choiceOrPressureId = 'choice_or_pressure';
  static const whereRepeatId = 'where_repeat';
  static const whatFearedId = 'what_feared';
  static const fearProvenWrongId = 'fear_proven_wrong';

  List<ArchiveReflectionQuestion> questions() => const [
        ArchiveReflectionQuestion(
          id: choiceOrPressureId,
          prompt: 'Was this choice or pressure?',
        ),
        ArchiveReflectionQuestion(
          id: whereRepeatId,
          prompt: 'Where does this repeat?',
        ),
        ArchiveReflectionQuestion(
          id: whatFearedId,
          prompt: 'What did I fear would happen if I stopped?',
        ),
        ArchiveReflectionQuestion(
          id: fearProvenWrongId,
          prompt: 'Has that fear been proven wrong?',
        ),
      ];

  ArchiveReflectionAnswer answer(
    String questionId,
    List<PressureCheckInRecord> records,
  ) {
    switch (questionId) {
      case choiceOrPressureId:
        return _choiceOrPressure(records);
      case whereRepeatId:
        return _whereRepeat(records);
      case whatFearedId:
        return _whatFeared(records);
      case fearProvenWrongId:
        return _fearProvenWrong(records);
      default:
        return _insufficient();
    }
  }

  ArchiveReflectionAnswer _choiceOrPressure(
    List<PressureCheckInRecord> records,
  ) {
    if (records.length < 2) return _insufficient();
    final stopped = records.where((r) => r.choseToStop).length;
    if (stopped > 0) {
      return ArchiveReflectionAnswer(
        text: 'You noticed pressure ${records.length} times and chose to stop '
            '$stopped of them — so far both choice and pressure show up.',
        hasEvidence: true,
      );
    }
    return ArchiveReflectionAnswer(
      text: 'Across ${records.length} moments, this looked more like pressure '
          'than free choice so far.',
      hasEvidence: true,
    );
  }

  ArchiveReflectionAnswer _whereRepeat(List<PressureCheckInRecord> records) {
    final counts = <String, int>{};
    for (final record in records) {
      for (final context in record.contexts) {
        counts[context.id] = (counts[context.id] ?? 0) + 1;
      }
    }
    String? topId;
    var topCount = 0;
    counts.forEach((id, count) {
      if (count > topCount) {
        topCount = count;
        topId = id;
      }
    });
    if (topCount < 2) return _insufficient();
    final label = PressureContext.fromId(topId)?.label;
    if (label == null) return _insufficient();
    return ArchiveReflectionAnswer(
      text: 'So far this shows up most around ${label.toLowerCase()} '
          '($topCount moments).',
      hasEvidence: true,
    );
  }

  ArchiveReflectionAnswer _whatFeared(List<PressureCheckInRecord> records) {
    for (final record in records) {
      final fear = record.fear?.trim();
      if (fear != null && fear.isNotEmpty) {
        return ArchiveReflectionAnswer(
          text: 'You feared: "$fear"',
          hasEvidence: true,
        );
      }
    }
    return _insufficient();
  }

  ArchiveReflectionAnswer _fearProvenWrong(
    List<PressureCheckInRecord> records,
  ) {
    final hasFear = records.any((r) {
      final fear = r.fear?.trim();
      return fear != null && fear.isNotEmpty;
    });
    final stopped = records.where((r) => r.choseToStop).length;

    // Never claim a fear has been disproven — the archive can only note that
    // testing has begun and that it does not yet hold the evidence to say so.
    if (records.length >= 3 && stopped >= 1 && hasFear) {
      return const ArchiveReflectionAnswer(
        text: "You've started testing this by choosing to stop at least once — "
            'but your archive needs more evidence before it can answer that '
            'confidently.',
        hasEvidence: true,
      );
    }
    return _insufficient();
  }

  ArchiveReflectionAnswer _insufficient() => const ArchiveReflectionAnswer(
        text: insufficientEvidence,
        hasEvidence: false,
      );
}
