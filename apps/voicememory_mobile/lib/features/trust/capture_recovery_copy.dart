/// Canonical recovery copy — calm, actionable, no coaching language.
abstract final class CaptureRecoveryCopy {
  CaptureRecoveryCopy._();

  static const micDeniedBody =
      'Microphone access is off. Turn it on in Settings, or use text if available.';

  static const recordingFailed =
      'Recording did not start. Try again, or save a short text moment.';

  static const saveFailed = 'That moment was not saved. Please try again.';

  static const transcriptUnavailable =
      'ArchiveMe saved the moment, but the transcript may need another try.';

  static const noClearMatchYet =
      'No clear match yet — that is okay. Record the next real moment.';

  static const returnedAfterDelayTitle = 'Welcome back';

  static const returnedAfterDelayBody =
      'Record what came up today — short is fine.';

  static const simulatorMicHelper =
      'In Simulator, reset privacy permissions or use text if available.';

  static const testBuildEntitlementTimeout =
      'Pro status could not load right now. Recording and your archive still work.';

  static const testBuildNetworkUnavailable =
      'Network is unavailable in this build. Recording still works on this device.';

  static List<String> get all => [
        micDeniedBody,
        recordingFailed,
        saveFailed,
        transcriptUnavailable,
        noClearMatchYet,
        returnedAfterDelayTitle,
        returnedAfterDelayBody,
        simulatorMicHelper,
        testBuildEntitlementTimeout,
        testBuildNetworkUnavailable,
      ];
}
