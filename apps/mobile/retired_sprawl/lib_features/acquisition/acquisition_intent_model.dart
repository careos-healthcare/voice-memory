/// Why the user opened ArchiveMe — analytics only.
enum AcquisitionIntent {
  workPressure,
  relationships,
  habitsRepeat,
  decisionsRepeat,
  feelingStuck,
  notSureYet,
}

extension AcquisitionIntentIds on AcquisitionIntent {
  String get id => name;

  String get label {
    switch (this) {
      case AcquisitionIntent.workPressure:
        return 'Work pressure';
      case AcquisitionIntent.relationships:
        return 'Relationships';
      case AcquisitionIntent.habitsRepeat:
        return 'Habits I repeat';
      case AcquisitionIntent.decisionsRepeat:
        return 'Decisions I keep making';
      case AcquisitionIntent.feelingStuck:
        return 'Feeling stuck';
      case AcquisitionIntent.notSureYet:
        return 'Not sure yet';
    }
  }

  String get firstPrompt {
    switch (this) {
      case AcquisitionIntent.workPressure:
        return 'What felt heavy at work today?';
      case AcquisitionIntent.relationships:
        return 'What interaction kept replaying today?';
      case AcquisitionIntent.habitsRepeat:
        return 'What did you do again even though you noticed it?';
      case AcquisitionIntent.decisionsRepeat:
        return 'What choice did you repeat today?';
      case AcquisitionIntent.feelingStuck:
        return 'Where did you feel stuck today?';
      case AcquisitionIntent.notSureYet:
        return 'What happened, what did you do, and what felt heavy?';
    }
  }
}