import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/transcription_queue/transcription_queue_foreground_coordinator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('drains at startup and when connectivity returns', () async {
    final connectivity = StreamController<List<ConnectivityResult>>.broadcast(
      sync: true,
    );
    var drains = 0;
    final coordinator = TranscriptionQueueForegroundCoordinator(
      drain: () async => ++drains,
      connectivityChanges: connectivity.stream,
    );
    addTearDown(() async {
      await coordinator.dispose();
      await connectivity.close();
    });

    coordinator.start();
    await Future<void>.delayed(Duration.zero);
    expect(drains, 1);

    connectivity.add(const [ConnectivityResult.none]);
    await Future<void>.delayed(Duration.zero);
    expect(drains, 1);

    connectivity.add(const [ConnectivityResult.wifi]);
    await Future<void>.delayed(Duration.zero);
    expect(drains, 2);
  });
}
