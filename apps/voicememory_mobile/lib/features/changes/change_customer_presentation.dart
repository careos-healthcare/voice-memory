import 'change_thread.dart';

/// The single customer-facing vocabulary for Changes.
///
/// Domain statuses stay precise for projection and policy. Surfaces use this
/// mapper so internal direction and confidence never become competing primary
/// statuses.
class ChangeCustomerPresentation {
  const ChangeCustomerPresentation({
    required this.primaryStatus,
    this.secondaryExplanation,
    this.correctionMarker,
  });

  final String primaryStatus;
  final String? secondaryExplanation;
  final String? correctionMarker;
}

abstract final class ChangeCustomerPresentationMapper {
  ChangeCustomerPresentationMapper._();

  static const firstNoticed = 'First noticed';
  static const showingUpAgain = 'Showing up again';
  static const changed = 'Changed';

  static ChangeCustomerPresentation forStatus(
    ChangeThreadStatus status, {
    ChangeThreadCorrectionState correction = ChangeThreadCorrectionState.none,
  }) => ChangeCustomerPresentation(
    primaryStatus: switch (status) {
      ChangeThreadStatus.firstObserved => firstNoticed,
      ChangeThreadStatus.repeated ||
      ChangeThreadStatus.unresolved => showingUpAgain,
      ChangeThreadStatus.changed ||
      ChangeThreadStatus.weakened ||
      ChangeThreadStatus.strengthened => changed,
    },
    secondaryExplanation: switch (status) {
      ChangeThreadStatus.weakened => 'The signal appears weaker.',
      ChangeThreadStatus.strengthened => 'The signal appears stronger.',
      ChangeThreadStatus.unresolved => 'The evidence is mixed or uncertain.',
      _ => null,
    },
    correctionMarker: correction.marker,
  );

  static ChangeCustomerPresentation forThread(ChangeThread thread) =>
      forStatus(thread.currentStatus, correction: thread.correctionState);

  static ChangeCustomerPresentation forEvent(ChangeEvent event) =>
      forStatus(event.status, correction: event.correctionState);
}
