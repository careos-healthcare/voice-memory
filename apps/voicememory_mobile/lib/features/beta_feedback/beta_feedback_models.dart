/// Local beta feedback usefulness choice — never synced remotely.
enum BetaFeedbackUsefulness { useful, notYet }

/// Local beta feedback clarity choice — never synced remotely.
enum BetaFeedbackClarity { understood, confused }

/// Persisted beta feedback state — metadata only, no journal content.
class BetaFeedbackState {
  const BetaFeedbackState({
    this.dismissed = false,
    this.usefulness,
    this.clarity,
    this.note,
    this.testimonialCopied = false,
    this.updatedAt,
  });

  final bool dismissed;
  final BetaFeedbackUsefulness? usefulness;
  final BetaFeedbackClarity? clarity;
  final String? note;
  final bool testimonialCopied;
  final DateTime? updatedAt;

  static const empty = BetaFeedbackState();

  bool get hasResponse => usefulness != null || clarity != null;

  BetaFeedbackState copyWith({
    bool? dismissed,
    BetaFeedbackUsefulness? usefulness,
    bool clearUsefulness = false,
    BetaFeedbackClarity? clarity,
    bool clearClarity = false,
    String? note,
    bool clearNote = false,
    bool? testimonialCopied,
    DateTime? updatedAt,
  }) {
    return BetaFeedbackState(
      dismissed: dismissed ?? this.dismissed,
      usefulness: clearUsefulness ? null : (usefulness ?? this.usefulness),
      clarity: clearClarity ? null : (clarity ?? this.clarity),
      note: clearNote ? null : (note ?? this.note),
      testimonialCopied: testimonialCopied ?? this.testimonialCopied,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'dismissed': dismissed,
    if (usefulness != null) 'usefulness': usefulness!.name,
    if (clarity != null) 'clarity': clarity!.name,
    if (note != null && note!.trim().isNotEmpty) 'note': note!.trim(),
    if (testimonialCopied) 'testimonialCopied': true,
    if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
  };

  static BetaFeedbackState fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return empty;
    BetaFeedbackUsefulness? usefulness;
    final usefulnessRaw = json['usefulness'];
    if (usefulnessRaw is String) {
      for (final value in BetaFeedbackUsefulness.values) {
        if (value.name == usefulnessRaw) {
          usefulness = value;
          break;
        }
      }
    }
    BetaFeedbackClarity? clarity;
    final clarityRaw = json['clarity'];
    if (clarityRaw is String) {
      for (final value in BetaFeedbackClarity.values) {
        if (value.name == clarityRaw) {
          clarity = value;
          break;
        }
      }
    }
    DateTime? updatedAt;
    final updatedRaw = json['updatedAt'];
    if (updatedRaw is String) {
      updatedAt = DateTime.tryParse(updatedRaw);
    }
    final note = json['note'];
    return BetaFeedbackState(
      dismissed: json['dismissed'] == true,
      usefulness: usefulness,
      clarity: clarity,
      note: note is String && note.trim().isNotEmpty ? note.trim() : null,
      testimonialCopied: json['testimonialCopied'] == true,
      updatedAt: updatedAt,
    );
  }
}

/// Read-only beta proof summary — safe counts and labels only.
class BetaFeedbackSummary {
  const BetaFeedbackSummary({
    required this.momentsSavedCount,
    required this.depthLevelLabel,
    required this.watchThemesCount,
    required this.usefulnessLabel,
    required this.clarityLabel,
    required this.hasPrivateEntries,
    required this.feedbackState,
  });

  final int momentsSavedCount;
  final String depthLevelLabel;
  final int watchThemesCount;
  final String usefulnessLabel;
  final String clarityLabel;
  final bool hasPrivateEntries;
  final BetaFeedbackState feedbackState;
}
