/// Specificity of a post-save read.
enum ReadSpecificityLevel {
  low,
  medium,
  high,
}

extension ReadSpecificityLevelIds on ReadSpecificityLevel {
  String get id => name;
}

/// How the user responded to a read.
enum ReadUserAction {
  accepted,
  rejected,
  deeperOpened,
  alternativeChosen,
  ignored,
}

extension ReadUserActionIds on ReadUserAction {
  String get id => name;
}

/// Where the read came from.
enum ReadSourceKind {
  latestOnly,
  archiveRepeat,
  feedbackAdjusted,
  patternMemory,
}

extension ReadSourceKindIds on ReadSourceKind {
  String get id => name;
}

/// Internal quality label for retention analysis — not shown in consumer UI.
enum InterpretationQualityLabel {
  strong,
  weak,
  unclear,
}

extension InterpretationQualityLabelIds on InterpretationQualityLabel {
  String get id => name;
}

/// One scored post-save read for retention analysis.
class InterpretationQualitySignal {
  const InterpretationQualitySignal({
    required this.readId,
    required this.readTitle,
    required this.specificityLevel,
    this.strengthLabel,
    required this.evidenceCount,
    required this.userAction,
    this.timeToActionSeconds,
    required this.createdAt,
    required this.source,
    this.nextPromptUsed = false,
    this.qualityLabel,
  });

  final String readId;
  final String readTitle;
  final ReadSpecificityLevel specificityLevel;
  final String? strengthLabel;
  final int evidenceCount;
  final ReadUserAction userAction;
  final int? timeToActionSeconds;
  final DateTime createdAt;
  final ReadSourceKind source;
  final bool nextPromptUsed;
  final InterpretationQualityLabel? qualityLabel;

  Map<String, dynamic> toJson() => {
        'readId': readId,
        'readTitle': readTitle,
        'specificityLevel': specificityLevel.id,
        if (strengthLabel != null) 'strengthLabel': strengthLabel,
        'evidenceCount': evidenceCount,
        'userAction': userAction.id,
        if (timeToActionSeconds != null)
          'timeToActionSeconds': timeToActionSeconds,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'source': source.id,
        'nextPromptUsed': nextPromptUsed,
        if (qualityLabel != null) 'qualityLabel': qualityLabel!.id,
      };

  factory InterpretationQualitySignal.fromJson(Map<String, dynamic> json) {
    return InterpretationQualitySignal(
      readId: json['readId'] as String? ?? '',
      readTitle: json['readTitle'] as String? ?? '',
      specificityLevel: ReadSpecificityLevel.values.firstWhere(
        (e) => e.id == json['specificityLevel'],
        orElse: () => ReadSpecificityLevel.medium,
      ),
      strengthLabel: json['strengthLabel'] as String?,
      evidenceCount: (json['evidenceCount'] as num?)?.toInt() ?? 0,
      userAction: ReadUserAction.values.firstWhere(
        (e) => e.id == json['userAction'],
        orElse: () => ReadUserAction.ignored,
      ),
      timeToActionSeconds: (json['timeToActionSeconds'] as num?)?.toInt(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      source: ReadSourceKind.values.firstWhere(
        (e) => e.id == json['source'],
        orElse: () => ReadSourceKind.latestOnly,
      ),
      nextPromptUsed: json['nextPromptUsed'] == true,
      qualityLabel: json['qualityLabel'] == null
          ? null
          : InterpretationQualityLabel.values.firstWhere(
              (e) => e.id == json['qualityLabel'],
              orElse: () => InterpretationQualityLabel.unclear,
            ),
    );
  }
}
