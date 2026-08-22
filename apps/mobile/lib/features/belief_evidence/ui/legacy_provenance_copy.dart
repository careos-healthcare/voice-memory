/// Copy for entries whose transcript origin was not recorded when they were
/// written, and for the action that can recover it.
///
/// Three rules shaped every line here.
///
/// It must not read as damage. This is the state of every entry in every
/// install that existed before provenance was recorded, so a user opening the
/// app tomorrow meets it on their whole history at once. Copy that sounds like
/// a fault would tell thousands of people something broke when what actually
/// happened is that the app started being careful.
///
/// It must not overstate. The app does not know the stored text is generated.
/// It knows it cannot prove the text is not generated, which is a weaker and
/// less frightening claim, and the only one the data supports.
///
/// It must survive the mechanism changing. On-device transcription is in
/// flight; when it lands, recovery stops involving a server and the consent
/// question disappears. So the action is written around checking wording
/// against a recording, and the server is described in a separate paragraph
/// that is shown only while a server is what does the work.
abstract final class LegacyProvenanceCopy {
  LegacyProvenanceCopy._();

  /// Header. States the outcome first, because that is what the user can see:
  /// the quote they expected is not there.
  static const String title = 'Not shown as a quote';

  /// Names the cause, then removes the two wrong readings a user could take
  /// from it — that something was lost, and that the text is known to be fake.
  static const String body =
      'This entry was saved before the app kept a record of where transcript '
      'text came from. Your entry is still saved, and so is its text. We '
      'cannot confirm the text is what you said rather than wording the app '
      'produced, so we do not show it inside quote marks.';

  /// Closes the loop for a reader who is now wondering what they broke.
  static const String helper =
      'Entries saved since that change can still be quoted. You do not need '
      'to do anything here.';

  static String semantics({required String recovery}) =>
      '$title. $body $helper $recovery';

  static const List<String> all = [title, body, helper];
}

/// Copy for the user-initiated recovery of an entry's transcript origin.
abstract final class ProvenanceRecoveryCopy {
  ProvenanceRecoveryCopy._();

  /// Names the goal, not the plumbing, so the label stays true when the work
  /// moves on-device.
  static const String actionLabel = 'Check the wording against your recording';

  static const String sheetTitle = 'Check the wording against your recording';

  static const String whatItDoes =
      'The app reads your saved recording again and writes down what it '
      'hears. If that matches the text on this entry, the entry can be quoted '
      'again.';

  /// Shown only while a server does the reading. Names the receiver, because
  /// "sent for processing" is not something a person can weigh.
  static const String remoteDisclosure =
      'Right now this reading happens on a server rather than on this device. '
      'Your recording would go to the ArchiveMe server, which passes it to '
      'OpenAI Whisper to be turned into text. The text comes back to this '
      'device.';

  static const String consentReminder =
      'This is why the check asks you first, and why it starts when you tap '
      'the button below and not before.';

  /// Scope, always stated before anything runs.
  static String scopeFor(int entryCount) => entryCount == 1
      ? 'This covers 1 entry.'
      : 'This covers $entryCount entries.';

  static String partialScopeFor({
    required int withAudio,
    required int total,
  }) =>
      'Of the $total entries here, $withAudio still have a saved recording. '
      'The check covers those.';

  static const String confirmLabel = 'Start the check';
  static const String cancelLabel = 'Not now';

  // ——— Reasons the check is not offered ———

  static const String audioMissing =
      'The recording for this entry is no longer on this device. There is no '
      'saved audio to read again, so the wording stays unconfirmed.';

  static const String audioMissingBulk =
      'These entries do not have a saved recording on this device, so there '
      'is no audio to read again.';

  /// Takes the switch's own label so this stays right if the switch is
  /// renamed, and so a user can find the exact row it names.
  static String onDeviceOnlyBlocker(String settingName) =>
      'To run this you would first turn off "$settingName" in Settings. It is '
      'on right now, which is why your recording stays on this device.';

  static const String transcriptionNotPermittedBlocker =
      'You would also give permission for recordings to be sent for '
      'transcription. That permission is off right now.';

  static String bothBlockers(String settingName) =>
      '${onDeviceOnlyBlocker(settingName)} '
      '$transcriptionNotPermittedBlocker';

  static const String blockedHeading = 'What would have to change first';

  // ——— Results ———

  static String outcomeRecovered({
    required int recovered,
    required int requested,
  }) => requested == 1
      ? 'Done. This entry can be quoted again.'
      : 'Done. $recovered of $requested entries can be quoted again.';

  static const String outcomeNoneRecovered =
      'The check finished without a match, so the wording here stays '
      'unconfirmed. Your entry and your recording are untouched.';

  static String actionSemantics(int entryCount) =>
      '$actionLabel. ${scopeFor(entryCount)} '
      'Opens a summary of what happens before anything runs.';

  static const List<String> all = [
    actionLabel,
    sheetTitle,
    whatItDoes,
    remoteDisclosure,
    consentReminder,
    confirmLabel,
    cancelLabel,
    audioMissing,
    audioMissingBulk,
    transcriptionNotPermittedBlocker,
    blockedHeading,
    outcomeNoneRecovered,
  ];
}
