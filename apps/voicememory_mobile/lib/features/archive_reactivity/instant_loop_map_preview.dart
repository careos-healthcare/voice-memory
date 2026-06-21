import 'package:flutter/foundation.dart';

import '../../models/journal_entry.dart';
import '../onboarding/aha_first_onboarding.dart';
import 'archive_display_copy_guard.dart';
import 'archive_thought_map.dart';

enum InstantLoopMapPreviewState {
  firstMoment,
  secondMoment,
  readyForFullMap,
  insufficient;

  String get logId => name;
}

class InstantLoopMapPreview {
  const InstantLoopMapPreview({
    required this.title,
    required this.triggerGuess,
    required this.thoughtGuess,
    required this.actionGuess,
    required this.nextQuestion,
    required this.strongestQuote,
    required this.confidenceLabel,
    required this.state,
    this.whatRepeated,
    this.showsExactQuote = true,
  });

  final String title;
  final String triggerGuess;
  final String thoughtGuess;
  final String actionGuess;
  final String nextQuestion;
  final String strongestQuote;
  final String confidenceLabel;
  final InstantLoopMapPreviewState state;
  final String? whatRepeated;
  final bool showsExactQuote;

  bool get showWhatRepeated =>
      whatRepeated?.trim().isNotEmpty == true &&
      state == InstantLoopMapPreviewState.secondMoment;

  String get valueLadderLine => switch (state) {
    InstantLoopMapPreviewState.firstMoment =>
      AhaFirstOnboardingCopy.afterFirstValueLadder,
    InstantLoopMapPreviewState.secondMoment =>
      AhaFirstOnboardingCopy.afterSecondValueLadder,
    _ => '',
  };

  String get primaryCtaLabel => switch (state) {
    InstantLoopMapPreviewState.firstMoment => 'Add one focused moment',
    InstantLoopMapPreviewState.secondMoment =>
      'Add final moment to unlock the full map',
    _ => 'Record the next time this shows up',
  };

  static const cardTitle = 'Your first map is starting';
  static const cardSubtitle =
      'ArchiveMe sketched the loop behind your words.';

  static const labelWhatYouSaid = 'What you said';
  static const labelWhatMayBeAbout = 'Your words point to';
  static const labelWhatToWatchNext = 'What to watch next';
  static const labelWhatRepeated = 'What repeated';

  // Legacy labels kept for callers that still reference them.
  static const labelPossibleTrigger = labelWhatMayBeAbout;
  static const labelPossibleThought = 'Possible thought';
  static const labelWhatHappenedNext = 'What happened next';
  static const labelQuestionToTest = labelWhatToWatchNext;
}

abstract class InstantLoopMapPreviewCopy {
  InstantLoopMapPreviewCopy._();

  static const earlyGuess = 'Early guess';
  static const gettingClearer = 'Getting clearer';
}

abstract class InstantLoopMapPreviewLog {
  InstantLoopMapPreviewLog._();

  static void resolved(InstantLoopMapPreviewState state) {
    debugPrint(
      'ARCHIVEME_INSTANT_LOOP_PREVIEW_RESOLVED state=${state.logId}',
    );
  }

  static void displayed({
    required String surface,
    required InstantLoopMapPreviewState state,
  }) {
    debugPrint(
      'ARCHIVEME_INSTANT_LOOP_PREVIEW_DISPLAYED surface=$surface state=${state.logId}',
    );
  }

  static void ctaTapped(String action) {
    debugPrint('ARCHIVEME_INSTANT_LOOP_PREVIEW_CTA_TAPPED action=$action');
  }
}

abstract class InstantLoopMapPreviewResolver {
  InstantLoopMapPreviewResolver._();

  static bool isPersonalFirstValuePreview(InstantLoopMapPreview? preview) {
    if (preview == null) return false;
    return preview.state == InstantLoopMapPreviewState.firstMoment ||
        preview.state == InstantLoopMapPreviewState.secondMoment;
  }

  static InstantLoopMapPreview? resolve({
    required List<JournalEntry> entries,
    JournalEntry? latestEntry,
    ArchiveThoughtMap? fullThoughtMap,
  }) {
    final sorted = List<JournalEntry>.from(entries)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (sorted.isEmpty) return null;

    if (fullThoughtMap?.hasEnoughEvidence == true) {
      InstantLoopMapPreviewLog.resolved(
        InstantLoopMapPreviewState.readyForFullMap,
      );
      return null;
    }

    final count = sorted.length;
    if (count >= 3) {
      InstantLoopMapPreviewLog.resolved(
        InstantLoopMapPreviewState.readyForFullMap,
      );
      return null;
    }

    final latest = latestEntry ?? sorted.first;
    final transcript = latest.transcript.trim();
    if (transcript.length < 8) {
      final preview = _insufficient(transcript);
      InstantLoopMapPreviewLog.resolved(preview.state);
      return preview;
    }

    if (count == 1) {
      final preview = _firstMoment(latest);
      InstantLoopMapPreviewLog.resolved(preview.state);
      return preview;
    }

    final preview = _secondMoment(sorted[0], sorted[1]);
    InstantLoopMapPreviewLog.resolved(preview.state);
    return preview;
  }

  static InstantLoopMapPreview _insufficient(String transcript) {
    final trimmed = transcript.trim();
    final hasSomeText = trimmed.isNotEmpty;
    final quote = hasSomeText
        ? 'You mentioned: \'$trimmed\''
        : '—';

    return InstantLoopMapPreview(
      title: InstantLoopMapPreview.cardTitle,
      triggerGuess: _guard(
        hasSomeText
            ? 'ArchiveMe needs one more sentence to map this clearly.'
            : 'A specific moment worth naming.',
      ),
      thoughtGuess: '',
      actionGuess: '',
      nextQuestion: _guard('What would you watch for if this came back?'),
      strongestQuote: quote,
      confidenceLabel: InstantLoopMapPreviewCopy.earlyGuess,
      state: InstantLoopMapPreviewState.insufficient,
      showsExactQuote: hasSomeText,
    );
  }

  static InstantLoopMapPreview _firstMoment(JournalEntry entry) {
    final transcript = entry.transcript.trim();
    final quote = _exactPhrase(transcript);

    return InstantLoopMapPreview(
      title: InstantLoopMapPreview.cardTitle,
      triggerGuess: _guard(_hypothesisFromTranscript(transcript)),
      thoughtGuess: '',
      actionGuess: '',
      nextQuestion: _guard(_nextWatchFromTranscript(transcript)),
      strongestQuote: quote,
      confidenceLabel: InstantLoopMapPreviewCopy.earlyGuess,
      state: InstantLoopMapPreviewState.firstMoment,
      showsExactQuote: true,
    );
  }

  static InstantLoopMapPreview _secondMoment(
    JournalEntry latest,
    JournalEntry earlier,
  ) {
    final latestText = latest.transcript.trim();
    final earlierText = earlier.transcript.trim();
    final quote = _exactPhrase(latestText);

    final whatRepeated = _whatRepeatedFromEntries(latestText, earlierText);

    return InstantLoopMapPreview(
      title: InstantLoopMapPreview.cardTitle,
      triggerGuess: _guard(_hypothesisFromTranscript(latestText)),
      thoughtGuess: '',
      actionGuess: '',
      nextQuestion: _guard(_nextWatchSecondMoment(latestText, earlierText)),
      strongestQuote: quote,
      confidenceLabel: InstantLoopMapPreviewCopy.gettingClearer,
      state: InstantLoopMapPreviewState.secondMoment,
      whatRepeated: whatRepeated,
      showsExactQuote: true,
    );
  }

  static String _exactPhrase(String transcript) => transcript.trim();

  static bool _isCheckingPattern(String transcript) {
    final lower = transcript.toLowerCase();
    final hasCheckCue = lower.contains('test') ||
        lower.contains('check') ||
        lower.contains('verify') ||
        lower.contains('proper') ||
        lower.contains('standard') ||
        lower.contains('trust');
    final hasWorkCue = lower.contains('work') ||
        lower.contains('app') ||
        lower.contains('enough') ||
        lower.contains('correct');
    return hasCheckCue && (hasWorkCue || lower.contains('again'));
  }

  static String _hypothesisFromTranscript(String transcript) {
    if (_isCheckingPattern(transcript)) {
      return 'Needing something to work properly before you can settle.';
    }
    final lower = transcript.toLowerCase();
    if (lower.contains('need') && lower.contains('work')) {
      return 'Needing something to work properly before you can settle.';
    }
    if (lower.contains('trust')) {
      return 'Needing enough proof before trust feels safe.';
    }
    if (lower.contains('avoid')) {
      return 'Trying to avoid something that feels risky.';
    }
    if (lower.contains('prove')) {
      return 'Trying to prove something is enough.';
    }
    if (lower.contains('replay') || lower.contains('again')) {
      return 'A moment that keeps returning in your mind.';
    }
    if (lower.contains('worry') || lower.contains('anxious')) {
      return 'Worrying about what might go wrong.';
    }
    return 'Something in this moment points to a repeating loop.';
  }

  static String _nextWatchFromTranscript(String transcript) {
    if (_isCheckingPattern(transcript)) {
      return 'After one useful check, does the need to check come back?';
    }
    final lower = transcript.toLowerCase();
    if (lower.contains('trust')) {
      return 'When doubt returns, what do you reach for first?';
    }
    if (lower.contains('avoid')) {
      return 'Next time this feeling returns, what do you do first?';
    }
    return 'If this feeling returns, what shows up first?';
  }

  static String _nextWatchSecondMoment(String latest, String earlier) {
    if (_isCheckingPattern(latest) || _isCheckingPattern(earlier)) {
      return 'After two checks, does the urge to verify settle or return?';
    }
    return 'What would a third moment confirm or challenge?';
  }

  static String _whatRepeatedFromEntries(String latest, String earlier) {
    if (_isCheckingPattern(latest) || _isCheckingPattern(earlier)) {
      return 'Both moments point toward needing something to feel correct '
          'before trust arrives.';
    }
    final latestLower = latest.toLowerCase();
    final earlierLower = earlier.toLowerCase();
    if (latestLower.contains('need') && earlierLower.contains('need')) {
      return 'Both moments carry a need to get something right.';
    }
    if (latestLower.contains('again') || earlierLower.contains('again')) {
      return 'Both moments suggest the same concern keeps returning.';
    }
    return 'Both moments rhyme — a similar concern may be repeating.';
  }

  static String _guard(String raw) {
    final approved = ArchiveDisplayCopyGuard.validateAndNormalize(
      field: 'hero',
      text: raw,
      allowShortLabel: true,
      requireSpecificity: false,
      allowGenericFallback: true,
    );
    return approved.isNotEmpty ? approved : raw.trim();
  }
}
