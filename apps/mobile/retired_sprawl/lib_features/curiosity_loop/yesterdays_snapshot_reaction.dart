/// One-tap quick reaction for the yesterday snapshot handoff.
enum YesterdaysSnapshotReaction {
  progressed,
  stuck,
  pivot;

  String get emoji {
    switch (this) {
      case YesterdaysSnapshotReaction.progressed:
        return '🟢';
      case YesterdaysSnapshotReaction.stuck:
        return '🟡';
      case YesterdaysSnapshotReaction.pivot:
        return '🔴';
    }
  }

  String get label {
    switch (this) {
      case YesterdaysSnapshotReaction.progressed:
        return 'Progressed';
      case YesterdaysSnapshotReaction.stuck:
        return 'Stuck';
      case YesterdaysSnapshotReaction.pivot:
        return 'Pivot';
    }
  }

  String get semanticsLabel {
    switch (this) {
      case YesterdaysSnapshotReaction.progressed:
        return 'Progressed since yesterday';
      case YesterdaysSnapshotReaction.stuck:
        return 'Stuck since yesterday';
      case YesterdaysSnapshotReaction.pivot:
        return 'Pivot since yesterday';
    }
  }
}