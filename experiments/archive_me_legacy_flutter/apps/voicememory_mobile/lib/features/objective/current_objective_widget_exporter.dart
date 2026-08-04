import 'current_objective_snapshot_builder.dart';
import 'current_objective_widget_snapshot.dart';

/// Default home-screen copy when snapshot data is missing.
const String kWidgetPayloadDefaultTitle = 'Today\u2019s check';
const String kWidgetPayloadDefaultBody = 'Open ArchiveMe to continue.';
const String kWidgetPayloadDefaultAction = 'Open';
const String kWidgetPayloadDefaultRoute = '/record';

/// Builds a platform-safe string map for native widgets.
Map<String, String> buildWidgetPayload(
  CurrentObjectiveWidgetSnapshot? snapshot,
) {
  if (snapshot == null) {
    return _defaults(updatedAt: DateTime.now().toUtc().toIso8601String());
  }

  return {
    'title': _cap(
      _nonEmpty(snapshot.title, kWidgetPayloadDefaultTitle),
      kWidgetSnapshotMaxTitleLength,
    ),
    'body': _cap(
      _nonEmpty(snapshot.body, kWidgetPayloadDefaultBody),
      kWidgetSnapshotMaxBodyLength,
    ),
    'checkQuestion': _cap(
      snapshot.checkQuestion?.trim() ?? '',
      kWidgetSnapshotMaxCheckQuestionLength,
    ),
    'primaryActionLabel': _cap(
      _nonEmpty(snapshot.primaryActionLabel, kWidgetPayloadDefaultAction),
      kWidgetSnapshotMaxActionLabelLength,
    ),
    'route': _nonEmpty(snapshot.route, kWidgetPayloadDefaultRoute),
    'type': snapshot.type.trim(),
    'updatedAt': snapshot.updatedAt.toUtc().toIso8601String(),
  };
}

Map<String, String> _defaults({required String updatedAt}) => {
  'title': kWidgetPayloadDefaultTitle,
  'body': kWidgetPayloadDefaultBody,
  'checkQuestion': '',
  'primaryActionLabel': kWidgetPayloadDefaultAction,
  'route': kWidgetPayloadDefaultRoute,
  'type': '',
  'updatedAt': updatedAt,
};

String _nonEmpty(String value, String fallback) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? fallback : trimmed;
}

String _cap(String value, int maxLength) {
  if (value.length <= maxLength) return value;
  if (maxLength <= 1) return value.substring(0, maxLength);
  return '${value.substring(0, maxLength - 1)}\u2026';
}
