/// Fixed contradiction options that challenge the proving-enough loop.
enum ProveEnoughContradictionOption {
  stoppedNothingBad(
    'stopped_nothing_bad',
    'I stopped and nothing bad happened',
  ),
  restedWithoutGuilt('rested_no_guilt', 'I rested without guilt'),
  effortChosen('effort_chosen', 'The effort felt chosen'),
  satisfiedNotBehind(
    'satisfied_not_behind',
    'I felt satisfied instead of behind',
  );

  const ProveEnoughContradictionOption(this.id, this.label);

  final String id;
  final String label;

  static ProveEnoughContradictionOption? fromId(String? raw) {
    if (raw == null) return null;
    for (final option in ProveEnoughContradictionOption.values) {
      if (option.id == raw) return option;
    }
    return null;
  }
}

/// Saved contradiction capture linked to a journey and/or entry.
class ProveEnoughContradictionRecord {
  const ProveEnoughContradictionRecord({
    required this.id,
    required this.option,
    required this.savedAt,
    this.journeyId,
    this.entryId,
  });

  final String id;
  final ProveEnoughContradictionOption option;
  final DateTime savedAt;
  final String? journeyId;
  final String? entryId;

  String get label => option.label;

  Map<String, dynamic> toJson() => {
    'id': id,
    'optionId': option.id,
    'label': option.label,
    'savedAt': savedAt.toIso8601String(),
    if (journeyId != null) 'journeyId': journeyId,
    if (entryId != null) 'entryId': entryId,
  };

  static ProveEnoughContradictionRecord? fromJson(Map<String, dynamic>? map) {
    if (map == null) return null;
    final id = map['id'] as String?;
    final option = ProveEnoughContradictionOption.fromId(
      map['optionId'] as String?,
    );
    final savedAt = DateTime.tryParse(map['savedAt'] as String? ?? '');
    if (id == null || option == null || savedAt == null) return null;
    return ProveEnoughContradictionRecord(
      id: id,
      option: option,
      savedAt: savedAt,
      journeyId: map['journeyId'] as String?,
      entryId: map['entryId'] as String?,
    );
  }
}
