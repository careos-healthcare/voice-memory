/// User-facing copy for the dedicated live voice session screen.
abstract final class LiveVoiceSessionCopy {
  LiveVoiceSessionCopy._();

  static const screenTitle = 'Live voice';
  static const recordEntryCta = 'Live conversation';
  static const reflectiveModeLabel = 'Reflective mode';
  static const liveConversationLabel = 'Live conversation';
  static const connecting = 'Connecting…';
  static const settingUp = 'Setting up…';
  static const listening = 'Listening…';
  static const speaking = 'Replying…';
  static const reconnecting = 'Reconnecting…';
  static const savingTitle = 'Saving your conversation';
  static const savingBody =
      'Turning what you said into a journal entry. This usually takes a moment.';
  static const transcriptTitle = 'Live transcript';
  static const transcriptEmpty = 'Your words will appear here as you speak.';
  static const cancel = 'Cancel';
  static const stopAndSave = 'Stop & save';
  static const discardTitle = 'Discard live voice?';
  static const discardBody = 'This conversation will not be saved.';
  static const discardConfirm = 'Discard';
  static const keepTalking = 'Keep talking';
  static const tryAgain = 'Try again';
  static const exitSession = 'Exit session';
  static const connectionLive = 'Live';
  static const connectionConnecting = 'Connecting';
  static const connectionReconnecting = 'Reconnecting';
  static const helperListening =
      'Speak naturally. Tap Stop & save when you are done.';
  static const helperSpeaking = 'Listening to the reply…';

  /// Says what live voice actually does, on the screen that does it.
  ///
  /// Live voice cannot work on-device: the audio goes to the backend proxy
  /// frame by frame while you are still speaking, which is how the reply
  /// arrives mid-sentence. `LiveAudioSessionCoordinator` will not open a
  /// session without consent for remote transcription, and this is the other
  /// half of that — a customer who granted the purpose should still be told,
  /// on the surface itself, what granting it means here.
  ///
  /// Deliberately narrow: it describes this session, and claims nothing about
  /// the rest of the app.
  static const remoteStreamingDisclosure =
      'Audio streams in real time. Your voice is sent to our server while you '
      'speak, and the transcript comes back the same way.';

  /// Shown when the gate refuses: consent for remote transcription is missing,
  /// or "Never send to server" is on.
  static const remoteProcessingRequiredTitle = 'Live voice needs remote '
      'processing';
  static const remoteProcessingRequiredBody =
      'This session works by sending audio to our server as you speak, so it '
      'needs remote transcription turned on. You can change that in Privacy '
      'settings. Recording on its own still works without it.';
}