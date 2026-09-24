/// The five low-friction pressure moments a user can log in one tap.
///
/// Copy stays inside the ArchiveMe product rule: catching the moment you do
/// more because stopping makes you feel behind, not a generic mood tracker.
enum PressureCheckInOption {
  didMoreToNotFeelBehind(
    id: 'did_more_to_not_feel_behind',
    label: "I did more so I wouldn't feel behind",
    momentPhrase: "I did more so I wouldn't feel behind.",
  ),
  couldNotStop(
    id: 'could_not_stop',
    label: "I couldn't stop even though I wanted to",
    momentPhrase: "I couldn't stop even though I wanted to.",
  ),
  hadToProveEnough(
    id: 'had_to_prove_enough',
    label: 'I felt I had to prove I was enough',
    momentPhrase: 'I felt I had to prove I was enough.',
  ),
  guiltyResting(
    id: 'guilty_resting',
    label: 'I felt guilty about resting',
    momentPhrase: 'I felt guilty about resting instead of doing more.',
  ),
  keptGoingToFeelProductive(
    id: 'kept_going_to_feel_productive',
    label: 'I kept going to feel productive',
    momentPhrase: 'I kept going because I needed to feel productive.',
  );

  const PressureCheckInOption({
    required this.id,
    required this.label,
    required this.momentPhrase,
  });

  /// Stable id persisted with the entry.
  final String id;

  /// Consumer-facing selectable label.
  final String label;

  /// Evidence-grade first-person sentence stored in the transcript.
  final String momentPhrase;

  static PressureCheckInOption? fromId(String? id) {
    if (id == null) return null;
    for (final option in PressureCheckInOption.values) {
      if (option.id == id) return option;
    }
    return null;
  }
}
