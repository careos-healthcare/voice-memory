/// User-selected signal waiting for confirmation on Patterns.
class SelectedSignalRecord {
  const SelectedSignalRecord({
    required this.id,
    required this.title,
    required this.categoryId,
    required this.strengthLabel,
    required this.nextPrompt,
    required this.savedAt,
    this.entryId,
    this.whySuggested,
    this.evidenceChips = const [],
    this.mightMean,
    this.wouldConfirm,
    this.wouldContradict,
    this.evidenceUsed,
    this.readId,
  });

  final String id;
  final String title;
  final String categoryId;
  final String strengthLabel;
  final String nextPrompt;
  final DateTime savedAt;
  final String? entryId;
  final String? whySuggested;
  final List<String> evidenceChips;
  final String? mightMean;
  final String? wouldConfirm;
  final String? wouldContradict;
  final String? evidenceUsed;
  final String? readId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'categoryId': categoryId,
        'strengthLabel': strengthLabel,
        'nextPrompt': nextPrompt,
        'savedAt': savedAt.toIso8601String(),
        if (entryId != null) 'entryId': entryId,
        if (whySuggested != null) 'whySuggested': whySuggested,
        'evidenceChips': evidenceChips,
        if (mightMean != null) 'mightMean': mightMean,
        if (wouldConfirm != null) 'wouldConfirm': wouldConfirm,
        if (wouldContradict != null) 'wouldContradict': wouldContradict,
        if (evidenceUsed != null) 'evidenceUsed': evidenceUsed,
        if (readId != null) 'readId': readId,
      };

  static SelectedSignalRecord? fromJson(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;
    final id = map['id'] as String?;
    final title = map['title'] as String?;
    final categoryId = map['categoryId'] as String?;
    final strengthLabel = map['strengthLabel'] as String?;
    final nextPrompt = map['nextPrompt'] as String?;
    final savedRaw = map['savedAt'] as String?;
    if (id == null ||
        title == null ||
        categoryId == null ||
        strengthLabel == null ||
        nextPrompt == null ||
        savedRaw == null) {
      return null;
    }
    final savedAt = DateTime.tryParse(savedRaw);
    if (savedAt == null) return null;
    final chipsRaw = map['evidenceChips'];
    final chips = chipsRaw is List
        ? chipsRaw.map((e) => e.toString()).toList()
        : const <String>[];
    return SelectedSignalRecord(
      id: id,
      title: title,
      categoryId: categoryId,
      strengthLabel: strengthLabel,
      nextPrompt: nextPrompt,
      savedAt: savedAt,
      entryId: map['entryId'] as String?,
      whySuggested: map['whySuggested'] as String?,
      evidenceChips: chips,
      mightMean: map['mightMean'] as String?,
      wouldConfirm: map['wouldConfirm'] as String?,
      wouldContradict: map['wouldContradict'] as String?,
      evidenceUsed: map['evidenceUsed'] as String?,
      readId: map['readId'] as String?,
    );
  }
}
