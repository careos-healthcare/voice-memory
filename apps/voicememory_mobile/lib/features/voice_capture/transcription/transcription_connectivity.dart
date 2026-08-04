import 'package:connectivity_plus/connectivity_plus.dart';

abstract interface class TranscriptionConnectivity {
  Future<bool> isOnline();
}

final class PlatformTranscriptionConnectivity
    implements TranscriptionConnectivity {
  PlatformTranscriptionConnectivity({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((result) => result != ConnectivityResult.none);
  }
}

final class FixedTranscriptionConnectivity
    implements TranscriptionConnectivity {
  const FixedTranscriptionConnectivity(this.online);

  final bool online;

  @override
  Future<bool> isOnline() async => online;
}
