/// Pause before speech, measured on the device during playback.
class HesitationSignalSample {
  const HesitationSignalSample({
    required this.gapBeforeSpeechMs,
    this.pauseCount = 0,
  });

  final int gapBeforeSpeechMs;
  final int pauseCount;
}

/// Quiet that stayed in the recording instead of being skipped.
class SilenceRetentionSignalSample {
  const SilenceRetentionSignalSample({
    required this.silenceBeforeSpeechMs,
    required this.retainedSilenceMs,
  });

  final int silenceBeforeSpeechMs;
  final int retainedSilenceMs;
}

/// Local reading. Nothing here is sent off the device.
class LocalCoachReading {
  const LocalCoachReading({
    required this.hesitation,
    required this.silenceRetained,
    required this.note,
  });

  final bool hesitation;
  final bool silenceRetained;
  final String note;
}

/// Switches that tune the on-device coaching reading.
class LocalAiCoachingParameters {
  const LocalAiCoachingParameters({
    this.noticePauses = true,
    this.keepQuietStretches = true,
    this.writeShortNote = true,
  });

  factory LocalAiCoachingParameters.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return const LocalAiCoachingParameters();
    }
    return LocalAiCoachingParameters(
      noticePauses: json['noticePauses'] != false,
      keepQuietStretches: json['keepQuietStretches'] != false,
      writeShortNote: json['writeShortNote'] != false,
    );
  }

  final bool noticePauses;
  final bool keepQuietStretches;
  final bool writeShortNote;

  LocalAiCoachingParameters copyWith({
    bool? noticePauses,
    bool? keepQuietStretches,
    bool? writeShortNote,
  }) {
    return LocalAiCoachingParameters(
      noticePauses: noticePauses ?? this.noticePauses,
      keepQuietStretches: keepQuietStretches ?? this.keepQuietStretches,
      writeShortNote: writeShortNote ?? this.writeShortNote,
    );
  }

  Map<String, dynamic> toJson() => {
    'noticePauses': noticePauses,
    'keepQuietStretches': keepQuietStretches,
    'writeShortNote': writeShortNote,
  };
}

/// On-device reading of hesitation and silence retention during playback.
class LocalAICoach {
  const LocalAICoach();

  static const hesitationThresholdMs = 12000;
  static const silenceThresholdMs = 1500;

  LocalCoachReading duringPlayback({
    required HesitationSignalSample hesitation,
    required SilenceRetentionSignalSample silence,
    LocalAiCoachingParameters parameters = const LocalAiCoachingParameters(),
  }) {
    final hesitationPresent =
        parameters.noticePauses &&
        (hesitation.gapBeforeSpeechMs >= hesitationThresholdMs ||
            hesitation.pauseCount >= 2);
    final silenceRetained =
        parameters.keepQuietStretches &&
        silence.silenceBeforeSpeechMs >= silenceThresholdMs &&
        silence.retainedSilenceMs > 0;

    final note = !parameters.writeShortNote
        ? ''
        : switch ((hesitationPresent, silenceRetained)) {
            (true, true) => 'A pause showed up, and the quiet stretch stayed.',
            (true, false) => 'A pause showed up before speech.',
            (false, true) => 'The quiet stretch stayed in the playback.',
            (false, false) => 'Playback stayed steady.',
          };

    return LocalCoachReading(
      hesitation: hesitationPresent,
      silenceRetained: silenceRetained,
      note: note,
    );
  }
}
