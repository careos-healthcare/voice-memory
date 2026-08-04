import 'tomorrow_commitment_model.dart';

enum WatchForStatus { pending, checked, skipped }

enum WatchForResult { showedAgain, didNotShow, changedShape, unclear, none }

/// A specific watch-for prompt saved for the next return day.
class WatchForItem {
  const WatchForItem({
    required this.id,
    required this.createdAt,
    required this.targetDate,
    required this.text,
    required this.chips,
    required this.status,
    required this.result,
    this.sourceReflectionId,
    this.completedAt,
    this.patternTitle,
    this.shortPrompt,
    this.specificPrompt,
    this.situationHint,
    this.emotionalHint,
    this.checkInQuestion,
    this.promptStrength,
    this.comparisonHint,
    this.isSuppressed = false,
  });

  final String id;
  final DateTime createdAt;
  final DateTime targetDate;
  final String? sourceReflectionId;
  final String text;
  final List<String> chips;
  final WatchForStatus status;
  final WatchForResult result;
  final DateTime? completedAt;
  final String? patternTitle;
  final String? shortPrompt;
  final String? specificPrompt;
  final String? situationHint;
  final String? emotionalHint;
  final String? checkInQuestion;
  final String? promptStrength;

  /// Quick-answer hint from [ReturnCaptureStore] when completing on return day.
  final String? comparisonHint;

  /// Disables passive reminders until new evidence links to this target.
  final bool isSuppressed;

  /// Rich prompts from [WatchForPromptEngine]; legacy items use [text] only.
  bool get hasRichPrompt =>
      (specificPrompt ?? '').trim().isNotEmpty ||
      (shortPrompt ?? '').trim().isNotEmpty;

  String get displaySpecificPrompt {
    final rich = specificPrompt?.trim() ?? '';
    return rich.isNotEmpty ? rich : text;
  }

  String get displayShortPrompt {
    final rich = shortPrompt?.trim() ?? '';
    return rich.isNotEmpty ? rich : text;
  }

  static DateTime dateOnly(DateTime value) =>
      TomorrowCommitment.dateOnly(value);

  bool isDueOn(DateTime day) =>
      status == WatchForStatus.pending && dateOnly(targetDate) == dateOnly(day);

  WatchForItem copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? targetDate,
    String? sourceReflectionId,
    String? text,
    List<String>? chips,
    WatchForStatus? status,
    WatchForResult? result,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    String? patternTitle,
    String? shortPrompt,
    String? specificPrompt,
    String? situationHint,
    String? emotionalHint,
    String? checkInQuestion,
    String? promptStrength,
    String? comparisonHint,
    bool clearComparisonHint = false,
    bool? isSuppressed,
  }) {
    return WatchForItem(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      targetDate: targetDate ?? this.targetDate,
      sourceReflectionId: sourceReflectionId ?? this.sourceReflectionId,
      text: text ?? this.text,
      chips: chips ?? this.chips,
      status: status ?? this.status,
      result: result ?? this.result,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      patternTitle: patternTitle ?? this.patternTitle,
      shortPrompt: shortPrompt ?? this.shortPrompt,
      specificPrompt: specificPrompt ?? this.specificPrompt,
      situationHint: situationHint ?? this.situationHint,
      emotionalHint: emotionalHint ?? this.emotionalHint,
      checkInQuestion: checkInQuestion ?? this.checkInQuestion,
      promptStrength: promptStrength ?? this.promptStrength,
      comparisonHint: clearComparisonHint
          ? null
          : (comparisonHint ?? this.comparisonHint),
      isSuppressed: isSuppressed ?? this.isSuppressed,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'targetDate': dateOnly(targetDate).toIso8601String(),
    if (sourceReflectionId != null) 'sourceReflectionId': sourceReflectionId,
    'text': text,
    'chips': chips,
    'status': status.name,
    'result': result.name,
    if (completedAt != null)
      'completedAt': completedAt!.toUtc().toIso8601String(),
    if (patternTitle != null) 'patternTitle': patternTitle,
    if (shortPrompt != null) 'shortPrompt': shortPrompt,
    if (specificPrompt != null) 'specificPrompt': specificPrompt,
    if (situationHint != null) 'situationHint': situationHint,
    if (emotionalHint != null) 'emotionalHint': emotionalHint,
    if (checkInQuestion != null) 'checkInQuestion': checkInQuestion,
    if (promptStrength != null) 'promptStrength': promptStrength,
    if (comparisonHint != null) 'comparisonHint': comparisonHint,
    if (isSuppressed) 'isSuppressed': true,
  };

  static WatchForItem? fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return null;
    final id = json['id']?.toString() ?? '';
    final text = json['text']?.toString().trim() ?? '';
    final createdRaw = json['createdAt']?.toString();
    final targetRaw = json['targetDate']?.toString();
    if (id.isEmpty || text.isEmpty || createdRaw == null || targetRaw == null) {
      return null;
    }
    final createdAt = DateTime.tryParse(createdRaw);
    final targetDate = DateTime.tryParse(targetRaw);
    if (createdAt == null || targetDate == null) return null;

    final chipsRaw = json['chips'];
    final chips = chipsRaw is List
        ? chipsRaw
              .map((e) => e.toString().trim())
              .where((c) => c.isNotEmpty)
              .toList()
        : <String>[];

    DateTime? completedAt;
    final completedRaw = json['completedAt']?.toString();
    if (completedRaw != null) {
      completedAt = DateTime.tryParse(completedRaw)?.toLocal();
    }

    return WatchForItem(
      id: id,
      createdAt: createdAt.toLocal(),
      targetDate: dateOnly(targetDate),
      sourceReflectionId: json['sourceReflectionId']?.toString(),
      text: text,
      chips: chips,
      status: _parseStatus(json['status']?.toString() ?? ''),
      result: _parseResult(json['result']?.toString() ?? ''),
      completedAt: completedAt,
      patternTitle: json['patternTitle']?.toString(),
      shortPrompt: json['shortPrompt']?.toString(),
      specificPrompt: json['specificPrompt']?.toString(),
      situationHint: json['situationHint']?.toString(),
      emotionalHint: json['emotionalHint']?.toString(),
      checkInQuestion: json['checkInQuestion']?.toString(),
      promptStrength: json['promptStrength']?.toString(),
      comparisonHint: json['comparisonHint']?.toString(),
      isSuppressed: json['isSuppressed'] == true,
    );
  }

  static WatchForStatus _parseStatus(String raw) {
    switch (raw) {
      case 'checked':
        return WatchForStatus.checked;
      case 'skipped':
        return WatchForStatus.skipped;
      default:
        return WatchForStatus.pending;
    }
  }

  static WatchForResult _parseResult(String raw) {
    switch (raw) {
      case 'showedAgain':
        return WatchForResult.showedAgain;
      case 'didNotShow':
        return WatchForResult.didNotShow;
      case 'changedShape':
        return WatchForResult.changedShape;
      case 'unclear':
        return WatchForResult.unclear;
      default:
        return WatchForResult.none;
    }
  }
}
