/// Beta invite wedge variants for recruiting testers.
enum BetaInviteVariantId {
  general,
  workPatterns,
  journalingUpgrade,
  founderCreator,
  privateArchive,
}

/// Per-variant local copy counts — no invite text stored.
class BetaInviteVariantStats {
  const BetaInviteVariantStats({
    required this.variantId,
    this.shortCopiedCount = 0,
    this.fullCopiedCount = 0,
    this.taskCopiedCount = 0,
    this.lastCopiedAt,
  });

  final BetaInviteVariantId variantId;
  final int shortCopiedCount;
  final int fullCopiedCount;
  final int taskCopiedCount;
  final DateTime? lastCopiedAt;

  int get totalCopiedCount =>
      shortCopiedCount + fullCopiedCount + taskCopiedCount;

  BetaInviteVariantStats copyWith({
    int? shortCopiedCount,
    int? fullCopiedCount,
    int? taskCopiedCount,
    DateTime? lastCopiedAt,
  }) {
    return BetaInviteVariantStats(
      variantId: variantId,
      shortCopiedCount: shortCopiedCount ?? this.shortCopiedCount,
      fullCopiedCount: fullCopiedCount ?? this.fullCopiedCount,
      taskCopiedCount: taskCopiedCount ?? this.taskCopiedCount,
      lastCopiedAt: lastCopiedAt ?? this.lastCopiedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'variantId': variantId.name,
    'shortCopiedCount': shortCopiedCount,
    'fullCopiedCount': fullCopiedCount,
    'taskCopiedCount': taskCopiedCount,
    if (lastCopiedAt != null)
      'lastCopiedAt': lastCopiedAt!.toUtc().toIso8601String(),
  };

  static BetaInviteVariantStats fromJson(Map<String, dynamic> json) {
    BetaInviteVariantId? id;
    final rawId = json['variantId'];
    if (rawId is String) {
      for (final value in BetaInviteVariantId.values) {
        if (value.name == rawId) {
          id = value;
          break;
        }
      }
    }
    DateTime? lastCopiedAt;
    final lastRaw = json['lastCopiedAt'];
    if (lastRaw is String) lastCopiedAt = DateTime.tryParse(lastRaw);
    return BetaInviteVariantStats(
      variantId: id ?? BetaInviteVariantId.general,
      shortCopiedCount: json['shortCopiedCount'] is int
          ? json['shortCopiedCount'] as int
          : 0,
      fullCopiedCount: json['fullCopiedCount'] is int
          ? json['fullCopiedCount'] as int
          : 0,
      taskCopiedCount: json['taskCopiedCount'] is int
          ? json['taskCopiedCount'] as int
          : 0,
      lastCopiedAt: lastCopiedAt,
    );
  }
}

/// Aggregate beta invite copy tracking — metadata only.
class BetaInviteCopyStats {
  const BetaInviteCopyStats({this.records = const {}, this.lastVariantId});

  static const empty = BetaInviteCopyStats();

  final Map<BetaInviteVariantId, BetaInviteVariantStats> records;
  final BetaInviteVariantId? lastVariantId;

  int get totalCopiedCount {
    var total = 0;
    for (final record in records.values) {
      total += record.totalCopiedCount;
    }
    return total;
  }

  bool get testerTaskCopied =>
      records.values.any((record) => record.taskCopiedCount > 0);

  BetaInviteVariantStats statsFor(BetaInviteVariantId id) =>
      records[id] ?? BetaInviteVariantStats(variantId: id);

  BetaInviteCopyStats copyWith({
    Map<BetaInviteVariantId, BetaInviteVariantStats>? records,
    BetaInviteVariantId? lastVariantId,
  }) {
    return BetaInviteCopyStats(
      records: records ?? this.records,
      lastVariantId: lastVariantId ?? this.lastVariantId,
    );
  }

  Map<String, dynamic> toJson() => {
    'records': records.values.map((r) => r.toJson()).toList(),
    if (lastVariantId != null) 'lastVariantId': lastVariantId!.name,
  };

  static BetaInviteCopyStats fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return empty;
    final records = <BetaInviteVariantId, BetaInviteVariantStats>{};
    final rawRecords = json['records'];
    if (rawRecords is List) {
      for (final raw in rawRecords) {
        if (raw is! Map) continue;
        final map = raw is Map<String, dynamic>
            ? raw
            : Map<String, dynamic>.from(raw);
        final stats = BetaInviteVariantStats.fromJson(map);
        records[stats.variantId] = stats;
      }
    }
    BetaInviteVariantId? lastVariantId;
    final lastRaw = json['lastVariantId'];
    if (lastRaw is String) {
      for (final value in BetaInviteVariantId.values) {
        if (value.name == lastRaw) {
          lastVariantId = value;
          break;
        }
      }
    }
    return BetaInviteCopyStats(records: records, lastVariantId: lastVariantId);
  }
}

/// Read-only summary for Beta Outcomes dashboard.
class BetaInviteOutcomesSummary {
  const BetaInviteOutcomesSummary({
    required this.totalCopiedCount,
    required this.lastVariantLabel,
    required this.testerTaskCopied,
  });

  final int totalCopiedCount;
  final String lastVariantLabel;
  final bool testerTaskCopied;
}
