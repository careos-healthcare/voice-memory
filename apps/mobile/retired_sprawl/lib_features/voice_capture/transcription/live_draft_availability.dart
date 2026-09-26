/// Which on-device draft paths can run. A test can supply a fake.
class LiveDraftAvailability {
  const LiveDraftAvailability({
    this.treatAsAndroid = false,
    this.treatAsIos = false,
    this.sherpaReady = false,
    this.platformRecognizerReady = false,
    this.iosOnDeviceReady = false,
  });

  final bool treatAsAndroid;
  final bool treatAsIos;
  final bool sherpaReady;
  final bool platformRecognizerReady;
  final bool iosOnDeviceReady;

  bool get supportsStreaming {
    if (treatAsAndroid) return sherpaReady || platformRecognizerReady;
    if (treatAsIos) return iosOnDeviceReady || sherpaReady;
    return false;
  }
}
