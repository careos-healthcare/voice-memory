/// Lifecycle of the return trigger — the calm, local-only loop that invites
/// the user back at the next pressure moment. No notifications, no backend.
enum PressureReturnTriggerStatus {
  /// Not enough evidence yet and no accepted experiment.
  notEligible,

  /// Eligible to be offered; user hasn't decided yet.
  eligible,

  /// User tapped "I'll do this" — the Record screen reminder may show.
  accepted,

  /// User tapped "Not now" — stay quiet, don't re-offer.
  dismissed,
}

/// The return trigger offered after an accepted micro-experiment or once the
/// first pressure review exists. All copy is hedged and calm.
class PressureReturnTrigger {
  const PressureReturnTrigger({required this.status});

  static const triggerCopy =
      'Next time this pressure shows up, open ArchiveMe before you push '
      'through.';

  static const supportCopy =
      'Your archive gets clearer when you catch the moment before it turns '
      'into proving.';

  /// Pro-only richer wording shown alongside the trigger.
  static const proPatternCopy =
      'Your return trigger is tied to your current pressure pattern.';

  static const savedCopy = 'Return trigger saved.';

  final PressureReturnTriggerStatus status;

  /// Whether the Pressure Insights card should render at all.
  bool get show =>
      status == PressureReturnTriggerStatus.eligible ||
      status == PressureReturnTriggerStatus.accepted;

  bool get accepted => status == PressureReturnTriggerStatus.accepted;
}
