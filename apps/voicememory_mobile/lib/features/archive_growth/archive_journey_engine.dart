import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence.dart';
import '../archive_v1/archive_v1_models.dart';
import 'archive_growth_copy.dart';

enum ArchiveJourneyStepId {
  day1,
  day3,
  day7,
}

class ArchiveJourneyStep {
  const ArchiveJourneyStep({
    required this.id,
    required this.title,
    required this.instruction,
    required this.reward,
    required this.isUnlocked,
    required this.isComplete,
  });

  final ArchiveJourneyStepId id;
  final String title;
  final String instruction;
  final String reward;
  final bool isUnlocked;
  final bool isComplete;
}

class ArchiveJourneyView {
  const ArchiveJourneyView({
    required this.steps,
    required this.daysSinceFirstRecording,
    required this.recordingCount,
    required this.completedCount,
  });

  final List<ArchiveJourneyStep> steps;
  final int daysSinceFirstRecording;
  final int recordingCount;
  final int completedCount;
}

/// First wow moments — deterministic, no new AI.
abstract final class ArchiveJourneyEngine {
  ArchiveJourneyEngine._();

  static ArchiveJourneyView build({
    required List<JournalEntry> entries,
    ArchiveV1View? archiveV1,
    Set<ArchiveJourneyStepId> markedComplete = const {},
  }) {
    final eligible = archiveEligibleEvidenceEntries(entries);
    final count = eligible.length;
    final days = _daysSinceFirst(eligible);

    final day1Reward = _day1Observation(eligible);
    final day3Reward = _day3Pattern(eligible);
    final day7Reward = _day7Change(archiveV1, eligible);

    final day1Unlocked = count >= 1;
    final day3Unlocked = days >= 3 || count >= 3;
    final day7Unlocked = days >= 7 || count >= 7;

    ArchiveJourneyStep step(
      ArchiveJourneyStepId id,
      String title,
      String instruction,
      String reward,
      bool unlocked,
    ) {
      final autoComplete = switch (id) {
        ArchiveJourneyStepId.day1 => day1Unlocked && day1Reward.isNotEmpty,
        ArchiveJourneyStepId.day3 => day3Unlocked && day3Reward.isNotEmpty,
        ArchiveJourneyStepId.day7 => day7Unlocked && day7Reward.isNotEmpty,
      };
      return ArchiveJourneyStep(
        id: id,
        title: title,
        instruction: instruction,
        reward: reward,
        isUnlocked: unlocked,
        isComplete: markedComplete.contains(id) || autoComplete,
      );
    }

    final steps = [
      step(
        ArchiveJourneyStepId.day1,
        ArchiveJourneyCopy.day1Title,
        ArchiveJourneyCopy.day1Instruction,
        day1Reward.isEmpty ? ArchiveJourneyCopy.day1Pending : day1Reward,
        day1Unlocked,
      ),
      step(
        ArchiveJourneyStepId.day3,
        ArchiveJourneyCopy.day3Title,
        ArchiveJourneyCopy.day3Instruction,
        day3Reward.isEmpty ? ArchiveJourneyCopy.day3Pending : day3Reward,
        day3Unlocked,
      ),
      step(
        ArchiveJourneyStepId.day7,
        ArchiveJourneyCopy.day7Title,
        ArchiveJourneyCopy.day7Instruction,
        day7Reward.isEmpty ? ArchiveJourneyCopy.day7Pending : day7Reward,
        day7Unlocked,
      ),
    ];

    return ArchiveJourneyView(
      steps: steps,
      daysSinceFirstRecording: days,
      recordingCount: count,
      completedCount: steps.where((s) => s.isComplete).length,
    );
  }

  static int _daysSinceFirst(List<JournalEntry> eligible) {
    if (eligible.isEmpty) return 0;
    final sorted = [...eligible]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final first = sorted.first.createdAt;
    final days = DateTime.now().difference(first).inDays;
    return days < 0 ? 0 : days;
  }

  static String _day1Observation(List<JournalEntry> eligible) {
    if (eligible.isEmpty) return '';
    final latest = eligible.last;
    final r = latest.reflection;
    final obs = r.concreteObservation.trim();
    if (obs.length >= 16) {
      return 'The archive noticed uncertainty around: "${_short(obs, 80)}"';
    }
    final tension = r.tensionOrContradiction?.trim() ?? '';
    if (tension.length >= 12) {
      return 'The archive noticed: "${_short(tension, 80)}"';
    }
    final signal = r.repeatedSignal.trim();
    if (signal.length >= 12) {
      return 'The archive noticed: "${_short(signal, 80)}"';
    }
    return 'The archive noticed your first reflection is on the record.';
  }

  static String _day3Pattern(List<JournalEntry> eligible) {
    if (eligible.length < 2) return '';
    final counts = <String, int>{};
    for (final e in eligible) {
      for (final t in e.reflection.recurringThemes) {
        final key = t.trim().toLowerCase();
        if (key.length < 2) continue;
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) {
      if (eligible.length >= 3) {
        return 'You have mentioned similar concerns ${eligible.length} times.';
      }
      return '';
    }
    final top = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
    if (top.value < 3 && eligible.length < 3) return '';
    final n = top.value >= 3 ? top.value : eligible.length;
    return 'You have mentioned "${top.key}" $n times.';
  }

  static String _day7Change(ArchiveV1View? v1, List<JournalEntry> eligible) {
    if (v1 != null) {
      final feed = v1.changeFeed;
      if (feed.themesDecreasing.isNotEmpty) {
        final t = feed.themesDecreasing.first;
        return 'This concern appears less often than last week ("${t.label}").';
      }
      if (feed.beliefsWeakened.isNotEmpty) {
        return 'A belief is fading: "${_short(feed.beliefsWeakened.first.statement, 70)}"';
      }
      if (v1.surprises.observations.isNotEmpty) {
        return 'The archive noticed: "${_short(v1.surprises.observations.first.observation, 90)}"';
      }
      if (feed.themesIncreasing.isNotEmpty) {
        final t = feed.themesIncreasing.first;
        return 'Mentions of "${t.label}" are increasing in your archive.';
      }
    }
    if (eligible.length >= 7) {
      return 'Your archive now spans a week of reflections — change is easier to see.';
    }
    return '';
  }

  static String _short(String text, int max) {
    final t = text.trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max).trim()}…';
  }
}
