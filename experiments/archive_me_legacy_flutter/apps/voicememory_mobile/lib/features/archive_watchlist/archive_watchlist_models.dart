/// Preset watch theme for the archive watchlist.
class ArchiveWatchlistPreset {
  const ArchiveWatchlistPreset({required this.id, required this.label});

  final String id;
  final String label;
}

/// Local watch item metadata — never written to [JournalStore].
class ArchiveWatchlistItem {
  const ArchiveWatchlistItem({
    required this.id,
    required this.presetId,
    this.customLabel,
    required this.createdAt,
  });

  static const customPresetId = 'custom';

  final String id;
  final String presetId;
  final String? customLabel;
  final DateTime createdAt;

  bool get isValid {
    if (id.isEmpty || presetId.isEmpty) return false;
    if (presetId == customPresetId) {
      return customLabel != null && customLabel!.trim().isNotEmpty;
    }
    return true;
  }

  String resolveLabel(Iterable<ArchiveWatchlistPreset> presets) {
    if (presetId == customPresetId) {
      return customLabel?.trim() ?? '';
    }
    for (final preset in presets) {
      if (preset.id == presetId) return preset.label;
    }
    return customLabel?.trim() ?? '';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'presetId': presetId,
    if (customLabel != null && customLabel!.trim().isNotEmpty)
      'customLabel': customLabel!.trim(),
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  factory ArchiveWatchlistItem.fromJson(Map<String, dynamic> json) {
    final createdRaw = json['createdAt'] as String?;
    return ArchiveWatchlistItem(
      id: json['id'] as String? ?? '',
      presetId: json['presetId'] as String? ?? '',
      customLabel: json['customLabel'] as String?,
      createdAt: createdRaw != null
          ? DateTime.parse(createdRaw).toLocal()
          : DateTime.now(),
    );
  }
}

/// Match readout for one watch item — counts only, no raw entry text.
class ArchiveWatchlistItemResult {
  const ArchiveWatchlistItemResult({
    required this.item,
    required this.label,
    required this.matchCount,
  });

  final ArchiveWatchlistItem item;
  final String label;
  final int matchCount;

  bool get hasMatches => matchCount > 0;
}

/// Card-level readout for archive home.
class ArchiveWatchlistCardResult {
  const ArchiveWatchlistCardResult({
    required this.items,
    required this.itemResults,
    required this.showProLine,
    required this.atThemeLimit,
  });

  final List<ArchiveWatchlistItem> items;
  final List<ArchiveWatchlistItemResult> itemResults;
  final bool showProLine;
  final bool atThemeLimit;
}
