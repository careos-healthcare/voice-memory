/// User-reported change answer for What Changed v2.
enum WhatChangedV2Option {
  stronger,
  softer,
  same,
  differentResponse,
  somethingHelped,
}

extension WhatChangedV2OptionLabels on WhatChangedV2Option {
  String get label => switch (this) {
        WhatChangedV2Option.stronger => 'Felt stronger',
        WhatChangedV2Option.softer => 'Felt softer',
        WhatChangedV2Option.same => 'Felt the same',
        WhatChangedV2Option.differentResponse => 'I responded differently',
        WhatChangedV2Option.somethingHelped => 'Something helped',
      };

  String get analyticsValue => switch (this) {
        WhatChangedV2Option.stronger => 'stronger',
        WhatChangedV2Option.softer => 'softer',
        WhatChangedV2Option.same => 'same',
        WhatChangedV2Option.differentResponse => 'different_response',
        WhatChangedV2Option.somethingHelped => 'something_helped',
      };
}

/// One local change marker tied to a saved entry.
class WhatChangedV2Record {
  const WhatChangedV2Record({
    required this.entryId,
    required this.option,
    required this.entryCountAtCapture,
    required this.createdAt,
  });

  final String entryId;
  final WhatChangedV2Option option;
  final int entryCountAtCapture;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'entryId': entryId,
        'option': option.analyticsValue,
        'entryCountAtCapture': entryCountAtCapture,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  factory WhatChangedV2Record.fromJson(Map<String, dynamic> json) {
    final optionRaw = json['option']?.toString() ?? '';
    return WhatChangedV2Record(
      entryId: json['entryId']?.toString() ?? '',
      option: WhatChangedV2Option.values.firstWhere(
        (value) => value.analyticsValue == optionRaw,
        orElse: () => WhatChangedV2Option.same,
      ),
      entryCountAtCapture: json['entryCountAtCapture'] as int? ?? 0,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now().toUtc(),
    );
  }
}

/// Grounded then/now snippets for the comparison payoff.
class WhatChangedV2Comparison {
  const WhatChangedV2Comparison({
    required this.thenSnippet,
    required this.nowSnippet,
  });

  final String thenSnippet;
  final String nowSnippet;
}

/// Post-save prompt for one entry.
class WhatChangedV2Prompt {
  const WhatChangedV2Prompt({
    required this.entryId,
    required this.entryCount,
    required this.hasConfirmedRepeat,
    required this.options,
    this.comparison,
  });

  final String entryId;
  final int entryCount;
  final bool hasConfirmedRepeat;
  final List<WhatChangedV2Option> options;
  final WhatChangedV2Comparison? comparison;

  bool get hasComparison =>
      comparison != null &&
      comparison!.thenSnippet.isNotEmpty &&
      comparison!.nowSnippet.isNotEmpty;
}

/// Answered payoff with optional comparison for secondary surfaces.
class WhatChangedV2AnsweredPayoff {
  const WhatChangedV2AnsweredPayoff({
    required this.option,
    required this.payoffLine,
    required this.comparison,
  });

  final WhatChangedV2Option option;
  final String payoffLine;
  final WhatChangedV2Comparison comparison;
}
