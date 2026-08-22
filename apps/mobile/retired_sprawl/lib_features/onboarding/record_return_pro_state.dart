/// Record → Return → Pro — the commercial activation loop.
///
/// Record once, saved as evidence, return tomorrow, see what changed,
/// Pro keeps the archive useful. Pure state and compile-time copy only:
/// no AI, no auto-notifications, nothing that blocks the first recording.
library;

import 'package:archiveme_mobile/features/activation/first_three_session_copy.dart';

/// Stable stage ids for analytics — fixed constants, never user text.
enum RecordReturnProStage {
  recordOnce('record_once'),
  evidence('evidence'),
  returnCue('return_cue'),
  changeStart('change_start'),
  proBridge('pro_bridge'),
  archiveValue('archive_value'),
  day2Return('day2_return');

  const RecordReturnProStage(this.id);

  final String id;
}

/// How the return cue was answered. Stable ids only.
abstract class RecordReturnProReturnCueMethod {
  RecordReturnProReturnCueMethod._();

  static const String reminder = 'reminder';
  static const String localCue = 'local_cue';
}

/// Persisted loop progress. Local only.
class RecordReturnProState {
  const RecordReturnProState({
    this.evidenceSeen = false,
    this.returnCueResolved = false,
    this.returnCueMethod,
    this.proBridgeResolved = false,
    this.changeStartSeen = false,
    this.loopStartedLogged = false,
  });

  final bool evidenceSeen;
  final bool returnCueResolved;
  final String? returnCueMethod;
  final bool proBridgeResolved;
  final bool changeStartSeen;
  final bool loopStartedLogged;

  RecordReturnProState copyWith({
    bool? evidenceSeen,
    bool? returnCueResolved,
    String? returnCueMethod,
    bool? proBridgeResolved,
    bool? changeStartSeen,
    bool? loopStartedLogged,
  }) {
    return RecordReturnProState(
      evidenceSeen: evidenceSeen ?? this.evidenceSeen,
      returnCueResolved: returnCueResolved ?? this.returnCueResolved,
      returnCueMethod: returnCueMethod ?? this.returnCueMethod,
      proBridgeResolved: proBridgeResolved ?? this.proBridgeResolved,
      changeStartSeen: changeStartSeen ?? this.changeStartSeen,
      loopStartedLogged: loopStartedLogged ?? this.loopStartedLogged,
    );
  }

  Map<String, dynamic> toJson() => {
    'evidenceSeen': evidenceSeen,
    'returnCueResolved': returnCueResolved,
    if (returnCueMethod != null) 'returnCueMethod': returnCueMethod,
    'proBridgeResolved': proBridgeResolved,
    'changeStartSeen': changeStartSeen,
    'loopStartedLogged': loopStartedLogged,
  };

  static RecordReturnProState fromJson(Map<String, dynamic>? json) {
    if (json == null) return const RecordReturnProState();
    return RecordReturnProState(
      evidenceSeen: json['evidenceSeen'] == true,
      returnCueResolved: json['returnCueResolved'] == true,
      returnCueMethod: json['returnCueMethod'] is String
          ? json['returnCueMethod'] as String
          : null,
      proBridgeResolved: json['proBridgeResolved'] == true,
      changeStartSeen: json['changeStartSeen'] == true,
      loopStartedLogged: json['loopStartedLogged'] == true,
    );
  }
}

/// Pure visibility gates — deterministic and unit-testable.
abstract class RecordReturnProGates {
  RecordReturnProGates._();

  /// Zero-entry record-once intro — never blocks recording.
  static bool showRecordOnceIntro({required int entryCount}) => entryCount == 0;

  /// First-save evidence card: only the moment the very first entry landed.
  static bool showEvidenceCard({
    required int entryCount,
    required bool justSaved,
  }) => entryCount == 1 && justSaved;

  /// Return cue: after the first save, until answered once.
  static bool showReturnCue({
    required int entryCount,
    required bool justSaved,
    required bool resolved,
  }) => entryCount == 1 && justSaved && !resolved;

  /// Pro bridge: after archive proof — never at zero or one entry, never on
  /// first save alone, never again once resolved.
  static bool showProBridge({
    required int entryCount,
    required bool resolved,
    required bool isPro,
    required bool hasArchiveProof,
  }) => entryCount >= 2 && hasArchiveProof && !resolved && !isPro;

  /// Archive value card: exactly one active entry.
  static bool showArchiveValue({required int entryCount}) => entryCount == 1;

  /// Generic change-can-begin card when real insight cards are not ready.
  static bool showChangeCanBegin({
    required int entryCount,
    required bool changeStartSeen,
    required bool hasRealChangeInsight,
  }) => entryCount >= 2 && !changeStartSeen && !hasRealChangeInsight;

  /// True when an existing engine already surfaces returned/faded/changed
  /// insight — suppresses the generic change-can-begin card.
  static bool hasRealChangeInsight({
    required bool hasReturnComparison,
    required bool hasTomorrowReturnLoopContent,
    required bool hasThreadReturnEvidence,
  }) =>
      hasReturnComparison ||
      hasTomorrowReturnLoopContent ||
      hasThreadReturnEvidence;
}

/// All consumer-facing copy — compile-time constants for test sweeps.
abstract class RecordReturnProCopy {
  RecordReturnProCopy._();

  // A. Record once.
  static const String recordOnceCta = 'Record one moment';
  static const String recordOnceSupporting =
      'Save small moments when something stands out — in your own words.';

  // B. Saved as evidence.
  static const String evidenceTitle = FirstThreeSessionCopy.session1Title;
  static const String evidenceBody = FirstThreeSessionCopy.session1Body;
  static const String evidenceSecondLine =
      FirstThreeSessionCopy.session1EnoughForToday;
  static const String evidenceThirdLine =
      FirstThreeSessionCopy.session1ReturnTomorrow;
  static const String evidenceViewArchive =
      FirstThreeSessionCopy.session1ViewArchive;
  static const String evidenceRecordAnother =
      FirstThreeSessionCopy.session1RecordAnother;

  // C. Return tomorrow.
  static const String returnTitle = 'Return tomorrow';
  static const String returnBody = FirstThreeSessionCopy.session1ReturnTomorrow;
  static const String returnLocalCta = 'I\u2019ll come back tomorrow';
  static const String returnRemindCta = 'Remind me tomorrow';

  // D. Change can begin.
  static const String changeTitle = 'Now change can begin to show';
  static const String changeBody =
      'With more than one entry, ArchiveMe can start comparing what feels '
      'new, repeated, or quieter.';
  static const String changeViewArchive = 'View archive';
  static const String changeSearchArchive = 'Search archive';

  // E. Pro archive continuity.
  static const String proTitle = FirstThreeSessionCopy.proTitle;
  static const String proBody = FirstThreeSessionCopy.proBody;
  static const String proContinuityLine =
      FirstThreeSessionCopy.proContinuityLine;
  static const String proCta = 'See Pro';
  static const String proSecondary = 'Not now';

  // Archive view helper (one entry).
  static const String archiveTitle = 'Your archive has started';
  static const String archiveBody =
      'Search it, pin what matters, or return tomorrow to compare what '
      'changed.';
  static const String archiveSearchAction = 'Search archive';
  static const String archivePinAction = 'Pin this entry';
  static const String archiveRecordAnother = 'Add one more moment';

  static const List<String> all = [
    recordOnceCta,
    recordOnceSupporting,
    evidenceTitle,
    evidenceBody,
    evidenceSecondLine,
    evidenceThirdLine,
    evidenceViewArchive,
    evidenceRecordAnother,
    returnTitle,
    returnBody,
    returnLocalCta,
    returnRemindCta,
    changeTitle,
    changeBody,
    changeViewArchive,
    changeSearchArchive,
    proTitle,
    proBody,
    proContinuityLine,
    proCta,
    proSecondary,
    archiveTitle,
    archiveBody,
    archiveSearchAction,
    archivePinAction,
    archiveRecordAnother,
  ];
}