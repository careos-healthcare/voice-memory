/// Surfaces that stay hidden until the archive has enough history.
enum ProgressiveSurface {
  beliefShiftGraphs,
  vectorRetrievalHyperparameters,
  deepRagConfiguration,
}

/// Usage snapshot used to decide which advanced tools may appear.
final class UserMilestoneSnapshot {
  const UserMilestoneSnapshot({
    required this.journalEntryCount,
    required this.daysActive,
    required this.activeDayKeys,
  });

  static const empty = UserMilestoneSnapshot(
    journalEntryCount: 0,
    daysActive: 0,
    activeDayKeys: {},
  );

  final int journalEntryCount;
  final int daysActive;
  final Set<String> activeDayKeys;

  bool isUnlocked(ProgressiveSurface surface) {
    final requirement = ProgressiveDisclosure.requirementFor(surface);
    return journalEntryCount >= requirement.minEntries &&
        daysActive >= requirement.minActiveDays;
  }

  double progressToward(ProgressiveSurface surface) {
    final requirement = ProgressiveDisclosure.requirementFor(surface);
    final entryProgress = requirement.minEntries == 0
        ? 1.0
        : (journalEntryCount / requirement.minEntries).clamp(0.0, 1.0);
    final dayProgress = requirement.minActiveDays == 0
        ? 1.0
        : (daysActive / requirement.minActiveDays).clamp(0.0, 1.0);
    return (entryProgress + dayProgress) / 2;
  }
}

/// Entry + active-day floor for one [ProgressiveSurface].
final class ProgressiveRequirement {
  const ProgressiveRequirement({
    required this.minEntries,
    required this.minActiveDays,
  });

  final int minEntries;
  final int minActiveDays;
}

/// Progressive-disclosure thresholds for advanced archive tools.
abstract final class ProgressiveDisclosure {
  ProgressiveDisclosure._();

  static const beliefShiftGraphs = ProgressiveRequirement(
    minEntries: 3,
    minActiveDays: 2,
  );

  static const vectorRetrievalHyperparameters = ProgressiveRequirement(
    minEntries: 5,
    minActiveDays: 3,
  );

  static const deepRagConfiguration = ProgressiveRequirement(
    minEntries: 7,
    minActiveDays: 5,
  );

  static ProgressiveRequirement requirementFor(ProgressiveSurface surface) {
    return switch (surface) {
      ProgressiveSurface.beliefShiftGraphs => beliefShiftGraphs,
      ProgressiveSurface.vectorRetrievalHyperparameters =>
        vectorRetrievalHyperparameters,
      ProgressiveSurface.deepRagConfiguration => deepRagConfiguration,
    };
  }
}

/// Copy for locked / unlocked advanced-tool rows.
abstract final class ProgressiveDisclosureCopy {
  ProgressiveDisclosureCopy._();

  static const settingsSectionTitle = 'Advanced tools';
  static const settingsSectionSubtitle =
      'These stay put away until you have a few saved moments to work with.';

  static const onboardingTitle = 'Advanced tools wait until you have a rhythm';
  static const onboardingBody =
      'Then-versus-now graphs, search tuning, and retrieval controls unlock '
      'after a handful of saved moments — not on the first open.';

  static const beliefShiftTitle = 'Then-versus-now graphs';
  static const beliefShiftSubtitle =
      'Side-by-side graphs that compare how a view moved.';

  static const vectorTitle = 'Search ranking';
  static const vectorSubtitle =
      'Candidate pool size and reciprocal-rank fusion weight.';

  static const ragTitle = 'Deep RAG';
  static const ragSubtitle =
      'How many retrieved archive chunks feed local follow-up.';

  static String lockedHint({
    required int entriesNeeded,
    required int daysNeeded,
    required int entriesHave,
    required int daysHave,
  }) {
    final entryLeft = (entriesNeeded - entriesHave).clamp(0, entriesNeeded);
    final dayLeft = (daysNeeded - daysHave).clamp(0, daysNeeded);
    if (entryLeft == 0 && dayLeft == 0) return 'Ready to open';
    if (entryLeft > 0 && dayLeft > 0) {
      return '$entryLeft more saved moment${entryLeft == 1 ? '' : 's'} · '
          '$dayLeft more active day${dayLeft == 1 ? '' : 's'}';
    }
    if (entryLeft > 0) {
      return '$entryLeft more saved moment${entryLeft == 1 ? '' : 's'}';
    }
    return '$dayLeft more active day${dayLeft == 1 ? '' : 's'}';
  }
}
