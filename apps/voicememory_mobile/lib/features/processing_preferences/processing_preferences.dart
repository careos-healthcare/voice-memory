/// Standing answers to the two processing questions ArchiveMe may ask.
///
/// Both default to asking every time. Nothing here is a recommendation: the
/// options are presented and stored with equal weight, and the private answer
/// is always reachable in one step.
library;

/// What should happen to the words of a new recording.
enum TranscriptionPreference {
  askEachTime('askEachTime'),
  onThisDevice('onThisDevice'),
  online('online'),
  saveWithoutTranscript('saveWithoutTranscript');

  const TranscriptionPreference(this.storageValue);

  final String storageValue;

  /// True when the stored answer would send audio off this device.
  bool get sendsAudioOffDevice => this == TranscriptionPreference.online;

  static TranscriptionPreference fromStorage(Object? value) =>
      values.firstWhere(
        (preference) => preference.storageValue == value,
        orElse: () => TranscriptionPreference.askEachTime,
      );
}

/// Whether ArchiveMe may produce a possible read of a saved moment.
enum InterpretationPreference {
  askEachTime('askEachTime'),
  generatePossibleRead('generatePossibleRead'),
  saveWithoutInterpretation('saveWithoutInterpretation');

  const InterpretationPreference(this.storageValue);

  final String storageValue;

  /// True when the stored answer would send text off this device.
  bool get sendsTextOffDevice =>
      this == InterpretationPreference.generatePossibleRead;

  static InterpretationPreference fromStorage(Object? value) =>
      values.firstWhere(
        (preference) => preference.storageValue == value,
        orElse: () => InterpretationPreference.askEachTime,
      );
}

/// One archive's stored answers.
final class ProcessingPreferences {
  const ProcessingPreferences({
    this.transcription = TranscriptionPreference.askEachTime,
    this.interpretation = InterpretationPreference.askEachTime,
  });

  static const askEveryTime = ProcessingPreferences();

  final TranscriptionPreference transcription;
  final InterpretationPreference interpretation;

  ProcessingPreferences copyWith({
    TranscriptionPreference? transcription,
    InterpretationPreference? interpretation,
  }) => ProcessingPreferences(
    transcription: transcription ?? this.transcription,
    interpretation: interpretation ?? this.interpretation,
  );

  Map<String, dynamic> toJson() => {
    'transcription': transcription.storageValue,
    'interpretation': interpretation.storageValue,
  };

  factory ProcessingPreferences.fromJson(Map<String, dynamic>? json) =>
      ProcessingPreferences(
        transcription: TranscriptionPreference.fromStorage(
          json?['transcription'],
        ),
        interpretation: InterpretationPreference.fromStorage(
          json?['interpretation'],
        ),
      );

  @override
  bool operator ==(Object other) =>
      other is ProcessingPreferences &&
      other.transcription == transcription &&
      other.interpretation == interpretation;

  @override
  int get hashCode => Object.hash(transcription, interpretation);
}

/// Consumer wording for the processing controls.
///
/// Every line states what actually happens: which service receives the data,
/// what it is used for, and what happens if the answer is no.
abstract final class ProcessingControlsCopy {
  static const screenTitle = 'AI and processing';
  static const settingsTileTitle = 'AI and processing';
  static const settingsTileSubtitle =
      'Choose what happens to your words, and what is sent';

  static const transcriptionSectionTitle = 'Turning a recording into text';
  static const transcriptionSectionBody =
      'This is asked after every recording unless you set an answer here. '
      'The recording itself is kept either way.';

  static const interpretationSectionTitle = 'Producing a possible read';
  static const interpretationSectionBody =
      'A possible read is one suggested interpretation of a saved moment. '
      'It is optional, it never replaces what you said, and you can ask for '
      'one later instead.';

  static const askEachTimeLabel = 'Ask me each time';
  static const askEachTimeDetail = 'No standing answer is stored.';

  static const onThisDeviceLabel = 'On this device';
  static const onThisDeviceDetail =
      'The local model reads the audio here. No upload.';
  static const onlineLabel = 'Online';
  static const onlineDetail =
      'The audio is uploaded to our server and sent to OpenAI to produce a '
      'transcript. You are asked to agree before the first upload.';
  static const saveWithoutTranscriptLabel = 'Save without transcript';
  static const saveWithoutTranscriptDetail =
      'Keep the recording as it is. Nothing is sent.';

  static const generatePossibleReadLabel = 'Generate possible read';
  static const generatePossibleReadDetail =
      'The text of the moment is uploaded to our server and sent to OpenAI to '
      'produce one possible read.';
  static const saveWithoutInterpretationLabel = 'Save without interpretation';
  static const saveWithoutInterpretationDetail =
      'Keep the moment exactly as you recorded it. Nothing is sent.';

  static const remoteExplanationTitle = 'What "online" actually means';
  static const remoteExplanationBody =
      'On-device transcription uses a local Whisper model and does not upload '
      'the recording. Online transcription uploads the audio file to the '
      'ArchiveMe server, which passes it to OpenAI Whisper and returns the '
      'text. A possible read separately uploads the saved text and eligible '
      'prior evidence to the server, which passes them to an OpenAI language '
      'model.\n\n'
      'Each remote purpose has its own choice and disclosure. Agreeing to '
      'transcription never agrees to interpretation. Saved originals do not '
      'depend on either request working.';

  static const permissionSectionTitle = 'Permission for online processing';
  static const permissionGrantedBody =
      'At least one online-processing disclosure is accepted. Withdrawing '
      'removes both transcription and interpretation acceptance for future '
      'requests.';
  static const permissionNotGrantedBody =
      'You have not agreed to online processing. Nothing is uploaded, and you '
      'will be asked before the first upload.';
  static const withdrawPermissionCta = 'Withdraw permission';
  static const permissionWithdrawnNote =
      'Permission withdrawn. Nothing is uploaded until you agree again.';

  static const scopeNote =
      'These answers are stored on this device only. They are not sent to the '
      'server and are not shared between accounts.';

  static String labelForTranscription(TranscriptionPreference preference) =>
      switch (preference) {
        TranscriptionPreference.askEachTime => askEachTimeLabel,
        TranscriptionPreference.onThisDevice => onThisDeviceLabel,
        TranscriptionPreference.online => onlineLabel,
        TranscriptionPreference.saveWithoutTranscript =>
          saveWithoutTranscriptLabel,
      };

  static String detailForTranscription(TranscriptionPreference preference) =>
      switch (preference) {
        TranscriptionPreference.askEachTime => askEachTimeDetail,
        TranscriptionPreference.onThisDevice => onThisDeviceDetail,
        TranscriptionPreference.online => onlineDetail,
        TranscriptionPreference.saveWithoutTranscript =>
          saveWithoutTranscriptDetail,
      };

  static String labelForInterpretation(InterpretationPreference preference) =>
      switch (preference) {
        InterpretationPreference.askEachTime => askEachTimeLabel,
        InterpretationPreference.generatePossibleRead =>
          generatePossibleReadLabel,
        InterpretationPreference.saveWithoutInterpretation =>
          saveWithoutInterpretationLabel,
      };

  static String detailForInterpretation(InterpretationPreference preference) =>
      switch (preference) {
        InterpretationPreference.askEachTime => askEachTimeDetail,
        InterpretationPreference.generatePossibleRead =>
          generatePossibleReadDetail,
        InterpretationPreference.saveWithoutInterpretation =>
          saveWithoutInterpretationDetail,
      };
}
