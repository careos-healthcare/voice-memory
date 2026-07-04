/// User-reported helped option — stored as safe enum, never inferred.
enum HelpedTrackingOption {
  paused,
  saidNo,
  askedForTime,
  talkedToSomeone,
  nothingHelped,
  somethingElse,
}

extension HelpedTrackingOptionLabels on HelpedTrackingOption {
  String get label => switch (this) {
        HelpedTrackingOption.paused => 'I paused',
        HelpedTrackingOption.saidNo => 'I said no',
        HelpedTrackingOption.askedForTime => 'I asked for time',
        HelpedTrackingOption.talkedToSomeone => 'I talked to someone',
        HelpedTrackingOption.nothingHelped => 'Nothing helped',
        HelpedTrackingOption.somethingElse => 'Something else',
      };

  String get analyticsValue => switch (this) {
        HelpedTrackingOption.paused => 'paused',
        HelpedTrackingOption.saidNo => 'said_no',
        HelpedTrackingOption.askedForTime => 'asked_for_time',
        HelpedTrackingOption.talkedToSomeone => 'talked_to_someone',
        HelpedTrackingOption.nothingHelped => 'nothing_helped',
        HelpedTrackingOption.somethingElse => 'something_else',
      };

  String get summaryVerb => switch (this) {
        HelpedTrackingOption.paused => 'paused',
        HelpedTrackingOption.saidNo => 'said no',
        HelpedTrackingOption.askedForTime => 'asked for time',
        HelpedTrackingOption.talkedToSomeone => 'talked to someone',
        HelpedTrackingOption.nothingHelped => 'marked nothing as helpful',
        HelpedTrackingOption.somethingElse => 'noted something else',
      };

  bool get countsAsHelped => this != HelpedTrackingOption.nothingHelped;
}

/// One local helped marker tied to a saved entry.
class HelpedTrackingRecord {
  const HelpedTrackingRecord({
    required this.entryId,
    required this.option,
    required this.entryCountAtCapture,
    required this.createdAt,
    this.freeText,
  });

  final String entryId;
  final HelpedTrackingOption option;
  final String? freeText;
  final int entryCountAtCapture;
  final DateTime createdAt;

  bool get hasFreeText => freeText != null && freeText!.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'entryId': entryId,
        'option': option.analyticsValue,
        if (freeText != null && freeText!.trim().isNotEmpty)
          'freeText': freeText!.trim(),
        'entryCountAtCapture': entryCountAtCapture,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  factory HelpedTrackingRecord.fromJson(Map<String, dynamic> json) {
    final optionRaw = json['option']?.toString() ?? '';
    return HelpedTrackingRecord(
      entryId: json['entryId']?.toString() ?? '',
      option: HelpedTrackingOption.values.firstWhere(
        (value) => value.analyticsValue == optionRaw,
        orElse: () => HelpedTrackingOption.nothingHelped,
      ),
      freeText: json['freeText']?.toString(),
      entryCountAtCapture: json['entryCountAtCapture'] as int? ?? 0,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now().toUtc(),
    );
  }
}

/// Post-save prompt for one entry.
class HelpedTrackingPrompt {
  const HelpedTrackingPrompt({
    required this.entryId,
    required this.entryCount,
    required this.options,
  });

  final String entryId;
  final int entryCount;
  final List<HelpedTrackingOption> options;
}
