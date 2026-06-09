import 'watch_for_model.dart';

enum ActivePatternThreadStatus {
  active,
  easing,
  changing,
  paused,
}

/// A named pattern thread the user continues day to day.
class ActivePatternThread {
  const ActivePatternThread({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.watchForText,
    required this.chips,
    required this.status,
    required this.daysActive,
    required this.lastResult,
    required this.nextPrompt,
    this.lastResultDate,
    this.recentMoments = const [],
    this.recentResults = const [],
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String watchForText;
  final List<String> chips;
  final ActivePatternThreadStatus status;
  final int daysActive;
  final WatchForResult lastResult;
  final DateTime? lastResultDate;
  final List<String> recentMoments;
  final List<WatchForResult> recentResults;
  final String nextPrompt;

  bool get isActive =>
      status == ActivePatternThreadStatus.active ||
      status == ActivePatternThreadStatus.easing ||
      status == ActivePatternThreadStatus.changing;

  bool get needsOneMoreMoment =>
      lastResult == WatchForResult.unclear &&
      status == ActivePatternThreadStatus.active;

  ActivePatternThread copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? watchForText,
    List<String>? chips,
    ActivePatternThreadStatus? status,
    int? daysActive,
    WatchForResult? lastResult,
    DateTime? lastResultDate,
    List<String>? recentMoments,
    List<WatchForResult>? recentResults,
    String? nextPrompt,
    bool clearLastResultDate = false,
  }) {
    return ActivePatternThread(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      watchForText: watchForText ?? this.watchForText,
      chips: chips ?? this.chips,
      status: status ?? this.status,
      daysActive: daysActive ?? this.daysActive,
      lastResult: lastResult ?? this.lastResult,
      lastResultDate:
          clearLastResultDate ? null : (lastResultDate ?? this.lastResultDate),
      recentMoments: recentMoments ?? this.recentMoments,
      recentResults: recentResults ?? this.recentResults,
      nextPrompt: nextPrompt ?? this.nextPrompt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'watchForText': watchForText,
        'chips': chips,
        'status': status.name,
        'daysActive': daysActive,
        'lastResult': lastResult.name,
        if (lastResultDate != null)
          'lastResultDate': lastResultDate!.toUtc().toIso8601String(),
        'recentMoments': recentMoments,
        'recentResults': recentResults.map((r) => r.name).toList(),
        'nextPrompt': nextPrompt,
      };

  static ActivePatternThread? fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return null;
    final id = json['id']?.toString() ?? '';
    final title = json['title']?.toString().trim() ?? '';
    if (id.isEmpty || title.isEmpty) return null;

    final createdAt = DateTime.tryParse(json['createdAt']?.toString() ?? '');
    final updatedAt = DateTime.tryParse(json['updatedAt']?.toString() ?? '');
    if (createdAt == null || updatedAt == null) return null;

    final chipsRaw = json['chips'];
    final chips = chipsRaw is List
        ? chipsRaw.map((e) => e.toString().trim()).where((c) => c.isNotEmpty).toList()
        : <String>[];

    final momentsRaw = json['recentMoments'];
    final moments = momentsRaw is List
        ? momentsRaw.map((e) => e.toString().trim()).where((m) => m.isNotEmpty).toList()
        : <String>[];

    final resultsRaw = json['recentResults'];
    final results = resultsRaw is List
        ? resultsRaw
            .map((e) => _parseResult(e.toString()))
            .where((r) => r != WatchForResult.none)
            .toList()
        : <WatchForResult>[];

    DateTime? lastResultDate;
    final lastRaw = json['lastResultDate']?.toString();
    if (lastRaw != null) {
      lastResultDate = DateTime.tryParse(lastRaw)?.toLocal();
    }

    return ActivePatternThread(
      id: id,
      title: title,
      createdAt: createdAt.toLocal(),
      updatedAt: updatedAt.toLocal(),
      watchForText: json['watchForText']?.toString().trim() ?? '',
      chips: chips,
      status: _parseStatus(json['status']?.toString() ?? ''),
      daysActive: (json['daysActive'] as num?)?.toInt() ?? 1,
      lastResult: _parseResult(json['lastResult']?.toString() ?? ''),
      lastResultDate: lastResultDate,
      recentMoments: moments.take(5).toList(),
      recentResults: results.take(5).toList(),
      nextPrompt: json['nextPrompt']?.toString().trim() ?? '',
    );
  }

  static ActivePatternThreadStatus _parseStatus(String raw) {
    switch (raw) {
      case 'easing':
        return ActivePatternThreadStatus.easing;
      case 'changing':
        return ActivePatternThreadStatus.changing;
      case 'paused':
        return ActivePatternThreadStatus.paused;
      default:
        return ActivePatternThreadStatus.active;
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
