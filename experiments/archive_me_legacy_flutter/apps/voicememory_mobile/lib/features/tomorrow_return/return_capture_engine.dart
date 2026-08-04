import 'watch_for_model.dart';
import 'return_capture_model.dart';

/// Builds return-day capture guidance from a pending watch-for.
class ReturnCaptureEngine {
  const ReturnCaptureEngine();

  static const List<String> _defaultStarters = [
    'Today, it showed up when…',
    'Compared with yesterday, it felt…',
    'The moment I noticed it was…',
    'What changed today was…',
  ];

  ReturnCaptureModel build({required WatchForItem pending}) {
    final prompt = pending.displaySpecificPrompt;
    final checkIn = pending.checkInQuestion?.trim();
    final starters = <String>[
      if (checkIn != null && checkIn.isNotEmpty) checkIn,
      ..._defaultStarters,
    ].take(4).toList();

    return ReturnCaptureModel(
      watchForId: pending.id,
      promptText: prompt,
      checkInQuestion: checkIn != null && checkIn.isNotEmpty ? checkIn : null,
      situationHint: pending.situationHint?.trim().isNotEmpty == true
          ? pending.situationHint
          : null,
      suggestedStarters: starters,
      quickAnswers: kDefaultReturnQuickAnswers,
      quality: _qualityFor(pending),
    );
  }

  ReturnQuickAnswer? quickAnswerById(String id) {
    for (final answer in kDefaultReturnQuickAnswers) {
      if (answer.id == id) return answer;
    }
    return null;
  }

  ReturnCaptureQuality _qualityFor(WatchForItem pending) {
    if (pending.hasRichPrompt &&
        (pending.checkInQuestion ?? '').trim().isNotEmpty) {
      return ReturnCaptureQuality.high;
    }
    if (pending.displaySpecificPrompt.length >= 48) {
      return ReturnCaptureQuality.medium;
    }
    return ReturnCaptureQuality.low;
  }
}
