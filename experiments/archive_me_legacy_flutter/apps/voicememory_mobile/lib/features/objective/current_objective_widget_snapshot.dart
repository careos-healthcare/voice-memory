/// Home-screen / lock-screen safe snapshot for future native widgets.
///
/// Contains only simple strings — no reflection text beyond [checkQuestion].
class CurrentObjectiveWidgetSnapshot {
  const CurrentObjectiveWidgetSnapshot({
    required this.title,
    required this.body,
    required this.primaryActionLabel,
    required this.route,
    required this.type,
    required this.updatedAt,
    this.checkQuestion,
  });

  final String title;
  final String body;
  final String? checkQuestion;
  final String primaryActionLabel;
  final String route;
  final String type;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'title': title,
    'body': body,
    if (checkQuestion != null && checkQuestion!.isNotEmpty)
      'checkQuestion': checkQuestion,
    'primaryActionLabel': primaryActionLabel,
    'route': route,
    'type': type,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  /// Parses [json] or returns null when data is missing or invalid.
  static CurrentObjectiveWidgetSnapshot? tryFromJson(
    Map<String, dynamic>? json,
  ) {
    if (json == null || json.isEmpty) return null;
    try {
      final title = json['title']?.toString().trim() ?? '';
      final body = json['body']?.toString().trim() ?? '';
      if (title.isEmpty || body.isEmpty) return null;

      final route = json['route']?.toString().trim();
      final primaryActionLabel =
          json['primaryActionLabel']?.toString().trim() ?? '';
      final type = json['type']?.toString().trim() ?? '';
      if (primaryActionLabel.isEmpty || type.isEmpty) return null;

      final checkRaw = json['checkQuestion']?.toString().trim();
      final checkQuestion = checkRaw != null && checkRaw.isNotEmpty
          ? checkRaw
          : null;

      final updatedRaw = json['updatedAt']?.toString();
      final updatedAt = updatedRaw != null
          ? DateTime.tryParse(updatedRaw)?.toUtc()
          : null;
      if (updatedAt == null) return null;

      return CurrentObjectiveWidgetSnapshot(
        title: title,
        body: body,
        checkQuestion: checkQuestion,
        primaryActionLabel: primaryActionLabel,
        route: route != null && route.isNotEmpty ? route : '/record',
        type: type,
        updatedAt: updatedAt,
      );
    } catch (_) {
      return null;
    }
  }

  factory CurrentObjectiveWidgetSnapshot.fromJson(Map<String, dynamic> json) {
    return tryFromJson(json) ??
        CurrentObjectiveWidgetSnapshot(
          title: json['title']?.toString() ?? '',
          body: json['body']?.toString() ?? '',
          primaryActionLabel: json['primaryActionLabel']?.toString() ?? '',
          route: json['route']?.toString() ?? '/record',
          type: json['type']?.toString() ?? '',
          updatedAt:
              DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
              DateTime.now().toUtc(),
          checkQuestion: json['checkQuestion']?.toString(),
        );
  }

  CurrentObjectiveWidgetSnapshot copyWith({
    String? title,
    String? body,
    String? checkQuestion,
    String? primaryActionLabel,
    String? route,
    String? type,
    DateTime? updatedAt,
  }) => CurrentObjectiveWidgetSnapshot(
    title: title ?? this.title,
    body: body ?? this.body,
    checkQuestion: checkQuestion ?? this.checkQuestion,
    primaryActionLabel: primaryActionLabel ?? this.primaryActionLabel,
    route: route ?? this.route,
    type: type ?? this.type,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
