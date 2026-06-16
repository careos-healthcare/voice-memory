/// What the user should focus on right now.
enum CurrentObjectiveType {
  recordFirstMoment,
  answerTodayCheck,
  chooseNextCheck,
  recordAnyMoment,
  doneForToday,
}

/// Consumer-visible current check / objective surfaced on Record and Patterns.
class CurrentObjective {
  const CurrentObjective({
    required this.type,
    required this.title,
    required this.body,
    required this.primaryCtaLabel,
    required this.route,
    this.checkQuestion,
    this.patternTitle,
    this.secondaryCtaLabel,
    this.targetDate,
  });

  final CurrentObjectiveType type;
  final String title;
  final String body;
  final String? checkQuestion;
  final String? patternTitle;
  final String primaryCtaLabel;
  final String? secondaryCtaLabel;
  final String route;
  final String? targetDate;

  String get typeId => type.name;

  Map<String, dynamic> toJson() => {
    'type': typeId,
    'title': title,
    'body': body,
    if (checkQuestion != null) 'checkQuestion': checkQuestion,
    if (patternTitle != null) 'patternTitle': patternTitle,
    'primaryCtaLabel': primaryCtaLabel,
    if (secondaryCtaLabel != null) 'secondaryCtaLabel': secondaryCtaLabel,
    'route': route,
    if (targetDate != null) 'targetDate': targetDate,
  };

  factory CurrentObjective.fromJson(Map<String, dynamic> json) {
    return CurrentObjective(
      type: _typeFromId(json['type']?.toString() ?? ''),
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      checkQuestion: json['checkQuestion']?.toString(),
      patternTitle: json['patternTitle']?.toString(),
      primaryCtaLabel: json['primaryCtaLabel']?.toString() ?? '',
      secondaryCtaLabel: json['secondaryCtaLabel']?.toString(),
      route: json['route']?.toString() ?? '/record',
      targetDate: json['targetDate']?.toString(),
    );
  }

  CurrentObjective copyWith({
    CurrentObjectiveType? type,
    String? title,
    String? body,
    String? checkQuestion,
    String? patternTitle,
    String? primaryCtaLabel,
    String? secondaryCtaLabel,
    String? route,
    String? targetDate,
  }) => CurrentObjective(
    type: type ?? this.type,
    title: title ?? this.title,
    body: body ?? this.body,
    checkQuestion: checkQuestion ?? this.checkQuestion,
    patternTitle: patternTitle ?? this.patternTitle,
    primaryCtaLabel: primaryCtaLabel ?? this.primaryCtaLabel,
    secondaryCtaLabel: secondaryCtaLabel ?? this.secondaryCtaLabel,
    route: route ?? this.route,
    targetDate: targetDate ?? this.targetDate,
  );

  static CurrentObjectiveType _typeFromId(String raw) {
    for (final type in CurrentObjectiveType.values) {
      if (type.name == raw) return type;
    }
    return CurrentObjectiveType.recordAnyMoment;
  }
}
