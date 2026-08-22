/// Lightweight, automatic tags ArchiveMe applies to a moment so it can later be
/// found by what it was about — no manual organising required.
enum MomentTag {
  work,
  family,
  partner,
  friend,
  money,
  sleep,
  pressure,
  worry,
  tired,
  avoided,
  lighter,
  heavier,
  changed,
  helped,
}

extension MomentTagInfo on MomentTag {
  String get id => name;

  /// Short, consumer-facing label.
  String get label {
    switch (this) {
      case MomentTag.work:
        return 'Work';
      case MomentTag.family:
        return 'Family';
      case MomentTag.partner:
        return 'Partner';
      case MomentTag.friend:
        return 'Friend';
      case MomentTag.money:
        return 'Money';
      case MomentTag.sleep:
        return 'Sleep';
      case MomentTag.pressure:
        return 'Pressure';
      case MomentTag.worry:
        return 'Worry';
      case MomentTag.tired:
        return 'Tired';
      case MomentTag.avoided:
        return 'Avoided';
      case MomentTag.lighter:
        return 'Lighter';
      case MomentTag.heavier:
        return 'Heavier';
      case MomentTag.changed:
        return 'Changed';
      case MomentTag.helped:
        return 'Helped';
    }
  }
}

MomentTag? momentTagFromId(String? id) {
  for (final t in MomentTag.values) {
    if (t.id == id) return t;
  }
  return null;
}