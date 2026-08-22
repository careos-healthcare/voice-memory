/// Trend label for a pattern across recent return comparisons.
enum ChangeSummaryStatus { stronger, softer, shifted, steady, unclear }

class ChangeSummary {
  const ChangeSummary({
    required this.title,
    required this.summary,
    required this.status,
    required this.chips,
    required this.createdAt,
  });

  final String title;
  final String summary;
  final ChangeSummaryStatus status;
  final List<String> chips;
  final DateTime createdAt;

  String get statusKey => status.name;

  Map<String, dynamic> toJson() => {
    'title': title,
    'summary': summary,
    'status': statusKey,
    'chips': chips,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  static ChangeSummary? fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return null;
    final title = json['title']?.toString().trim() ?? '';
    final summary = json['summary']?.toString().trim() ?? '';
    final atRaw = json['createdAt']?.toString();
    if (title.isEmpty || summary.isEmpty || atRaw == null) return null;
    final at = DateTime.tryParse(atRaw);
    if (at == null) return null;

    final chipsRaw = json['chips'];
    final chips = chipsRaw is List
        ? chipsRaw
              .map((e) => e.toString().trim())
              .where((c) => c.isNotEmpty)
              .toList()
        : <String>[];

    return ChangeSummary(
      title: title,
      summary: summary,
      status: _parseStatus(json['status']?.toString() ?? ''),
      chips: chips,
      createdAt: at.toLocal(),
    );
  }

  static ChangeSummaryStatus _parseStatus(String raw) {
    switch (raw) {
      case 'stronger':
        return ChangeSummaryStatus.stronger;
      case 'softer':
        return ChangeSummaryStatus.softer;
      case 'shifted':
        return ChangeSummaryStatus.shifted;
      case 'steady':
        return ChangeSummaryStatus.steady;
      default:
        return ChangeSummaryStatus.unclear;
    }
  }
}