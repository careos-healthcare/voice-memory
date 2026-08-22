/// First 60 Seconds — the commercial onboarding loop.
///
/// The first session keeps to one path: record once, see the save land,
/// know why tomorrow matters, understand how Pro continues the archive.
/// Everything here is
/// pure state and compile-time copy — no AI calls, no notifications, no
/// memory-architecture talk, and nothing that blocks recording.
library;

import 'package:archiveme_mobile/features/landing_continuity/landing_app_continuity_copy.dart';

/// Stable stage ids for analytics — fixed constants, never user text.
enum First60Stage {
  intro('intro'),
  firstSave('first_save'),
  returnCue('return_cue'),
  proBridge('pro_bridge'),
  archiveHelper('archive_helper');

  const First60Stage(this.id);

  /// Safe to log.
  final String id;
}

/// How the return cue was answered. Stable ids only.
abstract class First60ReturnCueMethod {
  First60ReturnCueMethod._();

  static const String reminder = 'reminder';
  static const String localCue = 'local_cue';
}

/// How the Pro bridge was resolved. Stable ids only.
abstract class First60ProBridgeOutcome {
  First60ProBridgeOutcome._();

  static const String tapped = 'tapped';
  static const String dismissed = 'dismissed';
}

/// Persisted first-60 progress. Local only — never synced, never logged
/// beyond the fixed stage ids above.
class First60SecondState {
  const First60SecondState({
    this.returnCueResolved = false,
    this.returnCueMethod,
    this.proBridgeResolved = false,
    this.firstSaveLogged = false,
  });

  /// The user answered the return cue (reminder or local intent).
  final bool returnCueResolved;

  /// One of [First60ReturnCueMethod], or null while unresolved.
  final String? returnCueMethod;

  /// The user answered the Pro bridge (saw Pro or said not now).
  final bool proBridgeResolved;

  /// The one-time first-save event already fired.
  final bool firstSaveLogged;

  First60SecondState copyWith({
    bool? returnCueResolved,
    String? returnCueMethod,
    bool? proBridgeResolved,
    bool? firstSaveLogged,
  }) {
    return First60SecondState(
      returnCueResolved: returnCueResolved ?? this.returnCueResolved,
      returnCueMethod: returnCueMethod ?? this.returnCueMethod,
      proBridgeResolved: proBridgeResolved ?? this.proBridgeResolved,
      firstSaveLogged: firstSaveLogged ?? this.firstSaveLogged,
    );
  }

  Map<String, dynamic> toJson() => {
    'returnCueResolved': returnCueResolved,
    if (returnCueMethod != null) 'returnCueMethod': returnCueMethod,
    'proBridgeResolved': proBridgeResolved,
    'firstSaveLogged': firstSaveLogged,
  };

  static First60SecondState fromJson(Map<String, dynamic>? json) {
    if (json == null) return const First60SecondState();
    return First60SecondState(
      returnCueResolved: json['returnCueResolved'] == true,
      returnCueMethod: json['returnCueMethod'] is String
          ? json['returnCueMethod'] as String
          : null,
      proBridgeResolved: json['proBridgeResolved'] == true,
      firstSaveLogged: json['firstSaveLogged'] == true,
    );
  }
}

/// Pure visibility gates — every first-60 surface decision in one place,
/// deterministic and unit-testable.
abstract class First60Gates {
  First60Gates._();

  /// Pre-record intro: only for a completely empty archive. Never blocks
  /// recording — it sits alongside the record controls.
  static bool showIntro({required int entryCount}) => entryCount == 0;

  /// First-save value card: only the moment the very first entry landed.
  static bool showValueCard({
    required int entryCount,
    required bool justSaved,
  }) => entryCount == 1 && justSaved;

  /// Tomorrow return cue: after the first save, until answered once.
  static bool showReturnCue({
    required int entryCount,
    required bool justSaved,
    required bool resolved,
  }) => entryCount == 1 && justSaved && !resolved;

  /// Pro bridge: only after archive proof — never before recording, never at
  /// zero or one entry, and never again once answered.
  static bool showProBridge({
    required int entryCount,
    required bool resolved,
    required bool hasArchiveProof,
  }) => entryCount >= 2 && hasArchiveProof && !resolved;

  /// Archive helper: exactly one active entry in the archive view.
  static bool showArchiveHelper({required int entryCount}) => entryCount == 1;
}

/// All consumer-facing first-60 copy — compile-time constants so tests can
/// sweep them. Preservation and future comparison only: no pattern claims
/// after one entry, no certainty, no memory-architecture talk.
abstract class First60Copy {
  First60Copy._();

  // A. First open / pre-record clarity.
  static const String introTitle = LandingAppContinuityCopy.hero;
  static const String introBody = LandingAppContinuityCopy.heroBody;
  static const String introCta = 'Record one moment';
  static const String introReassurance =
      'Your recordings stay on this device unless you choose sync or transcription.';

  // B. First save immediate value.
  static const String valueTitle = 'Saved to your archive';
  static const String valueBody =
      'This is now evidence you can return to later.';
  static const String valueSecondLine =
      'When patterns appear, ArchiveMe can show what returned, faded, or '
      'changed.';
  static const String valueCta = 'View my archive';
  static const String valueSecondary = 'Record another';
  static const String valueReassurance =
      'You can mark entries as exact evidence or keep them separate later.';

  // C. Tomorrow return reason.
  static const String returnTitle = 'Come back tomorrow';
  static const String returnBody =
      'One entry starts the archive. A second entry is where change begins '
      'to show.';
  static const String returnRemindCta = 'Remind me tomorrow';
  static const String returnLocalCta = 'I\u2019ll come back tomorrow';

  // D. Pro continuity bridge.
  static const String proTitle = 'Keep the longer proof trail';
  static const String proBody =
      'Unlock deeper history, saved evidence, and what keeps returning '
      'as your archive grows.';
  static const String proCta = 'See Pro';
  static const String proSecondary = 'Not now';

  // E. First archive view.
  static const String helperTitle = 'Your archive has started';
  static const String helperBody =
      'Search, pin, or return tomorrow to see what changes.';
  static const String helperSearchAction = 'Search archive';
  static const String helperPinAction = 'Pin this entry';

  /// Every consumer-facing line, for copy/banned-word sweeps.
  static const List<String> all = [
    introTitle,
    introBody,
    introCta,
    introReassurance,
    valueTitle,
    valueBody,
    valueSecondLine,
    valueCta,
    valueSecondary,
    valueReassurance,
    returnTitle,
    returnBody,
    returnRemindCta,
    returnLocalCta,
    proTitle,
    proBody,
    proCta,
    proSecondary,
    helperTitle,
    helperBody,
    helperSearchAction,
    helperPinAction,
  ];
}