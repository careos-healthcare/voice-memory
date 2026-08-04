import 'current_objective_model.dart';
import 'current_objective_widget_snapshot.dart';

/// Max lengths safe for home-screen / lock-screen widgets.
const int kWidgetSnapshotMaxTitleLength = 80;
const int kWidgetSnapshotMaxBodyLength = 120;
const int kWidgetSnapshotMaxCheckQuestionLength = 100;
const int kWidgetSnapshotMaxActionLabelLength = 40;

/// Builds a privacy-safe widget snapshot from a [CurrentObjective].
CurrentObjectiveWidgetSnapshot buildWidgetSnapshot(
  CurrentObjective objective, {
  DateTime? updatedAt,
}) {
  final route = objective.route.trim().isNotEmpty
      ? objective.route.trim()
      : '/record';

  return CurrentObjectiveWidgetSnapshot(
    title: _cap(_trim(objective.title), kWidgetSnapshotMaxTitleLength),
    body: _cap(_trim(objective.body), kWidgetSnapshotMaxBodyLength),
    checkQuestion: _optionalCap(
      objective.checkQuestion,
      kWidgetSnapshotMaxCheckQuestionLength,
    ),
    primaryActionLabel: _cap(
      _trim(objective.primaryCtaLabel),
      kWidgetSnapshotMaxActionLabelLength,
    ),
    route: route,
    type: objective.typeId,
    updatedAt: (updatedAt ?? DateTime.now()).toUtc(),
  );
}

String _trim(String value) => value.trim();

String _cap(String value, int maxLength) {
  if (value.length <= maxLength) return value;
  if (maxLength <= 1) return value.substring(0, maxLength);
  return '${value.substring(0, maxLength - 1)}\u2026';
}

String? _optionalCap(String? value, int maxLength) {
  if (value == null) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  return _cap(trimmed, maxLength);
}
