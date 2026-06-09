/// Outcome of comparing today's reflection with yesterday's watch-for commitment.
enum ReturnComparisonStatus {
  repeated,
  shifted,
  eased,
  absent,
  unclear,
}

class ReturnComparison {
  const ReturnComparison({
    required this.yesterdayWatchFor,
    required this.todayReflectionSummary,
    required this.comparisonStatus,
    required this.headline,
    required this.body,
    required this.chips,
    required this.createdAt,
  });

  final String yesterdayWatchFor;
  final String todayReflectionSummary;
  final ReturnComparisonStatus comparisonStatus;
  final String headline;
  final String body;
  final List<String> chips;
  final DateTime createdAt;

  String get statusKey => comparisonStatus.name;

  Map<String, dynamic> toJson() => {
        'yesterdayWatchFor': yesterdayWatchFor,
        'todayReflectionSummary': todayReflectionSummary,
        'comparisonStatus': statusKey,
        'headline': headline,
        'body': body,
        'chips': chips,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  static ReturnComparison? fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return null;
    final yesterday = json['yesterdayWatchFor']?.toString().trim() ?? '';
    final today = json['todayReflectionSummary']?.toString().trim() ?? '';
    final headline = json['headline']?.toString().trim() ?? '';
    final body = json['body']?.toString().trim() ?? '';
    final statusRaw = json['comparisonStatus']?.toString() ?? '';
    final atRaw = json['createdAt']?.toString();
    if (yesterday.isEmpty ||
        today.isEmpty ||
        headline.isEmpty ||
        body.isEmpty ||
        atRaw == null) {
      return null;
    }
    final at = DateTime.tryParse(atRaw);
    if (at == null) return null;

    final chipsRaw = json['chips'];
    final chips = chipsRaw is List
        ? chipsRaw
            .map((e) => e.toString().trim())
            .where((c) => c.isNotEmpty)
            .toList()
        : <String>[];

    return ReturnComparison(
      yesterdayWatchFor: yesterday,
      todayReflectionSummary: today,
      comparisonStatus: _parseStatus(statusRaw),
      headline: headline,
      body: body,
      chips: chips,
      createdAt: at.toLocal(),
    );
  }

  static ReturnComparisonStatus _parseStatus(String raw) {
    switch (raw) {
      case 'repeated':
        return ReturnComparisonStatus.repeated;
      case 'shifted':
        return ReturnComparisonStatus.shifted;
      case 'eased':
        return ReturnComparisonStatus.eased;
      case 'absent':
        return ReturnComparisonStatus.absent;
      default:
        return ReturnComparisonStatus.unclear;
    }
  }
}
