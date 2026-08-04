import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';

final class FakeSyncClock {
  FakeSyncClock(this.now);

  DateTime now;

  DateTime call() => now;

  void advance(Duration duration) {
    now = now.add(duration);
  }
}

/// A deterministic latency boundary. Calls announce entry and remain in-flight
/// until the test explicitly opens the gate.
final class CompleterGate {
  final Completer<void> _entered = Completer<void>();
  final Completer<void> _released = Completer<void>();

  Future<void> get entered => _entered.future;
  bool get isReleased => _released.isCompleted;

  Future<void> wait() async {
    if (!_entered.isCompleted) _entered.complete();
    await _released.future;
  }

  void open() {
    if (!_released.isCompleted) _released.complete();
  }
}

sealed class ScriptedOutcome<T> {
  const ScriptedOutcome({this.gate, this.onEntered});

  final CompleterGate? gate;
  final void Function()? onEntered;
}

final class ScriptedSuccess<T> extends ScriptedOutcome<T> {
  const ScriptedSuccess(this.value, {super.gate, super.onEntered});

  final T value;
}

final class ScriptedFailure<T> extends ScriptedOutcome<T> {
  const ScriptedFailure(this.error, {super.gate, super.onEntered});

  final Object error;
}

/// Typed scripted transport used by API and cloud transport fakes.
final class ScriptedTransport<Request, Response> {
  ScriptedTransport([Iterable<ScriptedOutcome<Response>> outcomes = const []])
    : _outcomes = List<ScriptedOutcome<Response>>.from(outcomes);

  final List<ScriptedOutcome<Response>> _outcomes;
  final List<Request> requests = <Request>[];

  void add(ScriptedOutcome<Response> outcome) => _outcomes.add(outcome);

  Future<Response> send(Request request) async {
    requests.add(request);
    if (_outcomes.isEmpty) {
      throw StateError('No scripted outcome remains for request $request.');
    }
    final outcome = _outcomes.removeAt(0);
    outcome.onEntered?.call();
    await outcome.gate?.wait();
    return switch (outcome) {
      ScriptedSuccess<Response>(:final value) => value,
      ScriptedFailure<Response>(:final error) => throw error,
    };
  }
}

final class FakeDelay {
  FakeDelay(this.clock);

  final FakeSyncClock clock;
  final List<Duration> calls = <Duration>[];
  final List<CompleterGate> gates = <CompleterGate>[];

  Future<void> call(Duration duration) async {
    calls.add(duration);
    clock.advance(duration);
    if (gates.isNotEmpty) await gates.removeAt(0).wait();
  }
}

/// Deterministic byte-window throttle. A request consumes one or more windows;
/// each exhausted window advances monotonic time and may be explicitly gated.
final class ByteBudgetThrottle {
  ByteBudgetThrottle({
    required this.clock,
    required this.bytesPerWindow,
    required this.window,
    this.gateWindows = false,
  }) : assert(bytesPerWindow > 0),
       assert(!window.isNegative);

  final FakeSyncClock clock;
  final int bytesPerWindow;
  final Duration window;
  final bool gateWindows;
  final List<int> byteCalls = <int>[];
  final List<CompleterGate> windowGates = <CompleterGate>[];
  int consumedBytes = 0;
  int windowsConsumed = 0;

  Future<void> consume(int bytes) async {
    if (bytes < 0) throw ArgumentError.value(bytes, 'bytes');
    byteCalls.add(bytes);
    consumedBytes += bytes;
    var remaining = bytes;
    while (remaining > 0) {
      remaining -= bytesPerWindow;
      windowsConsumed++;
      clock.advance(window);
      if (gateWindows) {
        final gate = CompleterGate();
        windowGates.add(gate);
        await gate.wait();
      }
    }
  }

  void releaseNextWindow() {
    final gate = windowGates.where((value) => !value.isReleased).firstOrNull;
    if (gate == null) {
      throw StateError('No throttled byte window is waiting.');
    }
    gate.open();
  }
}

final class ScriptedPacketDrop implements IOException {
  const ScriptedPacketDrop([this.message = 'scripted packet drop']);

  final String message;

  @override
  String toString() => 'ScriptedPacketDrop: $message';
}

sealed class NetworkOutcome<T> {
  const NetworkOutcome({this.gate, this.throttle});

  final CompleterGate? gate;
  final ByteBudgetThrottle? throttle;
}

final class NetworkSuccess<T> extends NetworkOutcome<T> {
  const NetworkSuccess(this.value, {super.gate, super.throttle});

  final T value;
}

final class NetworkPacketDrop<T> extends NetworkOutcome<T> {
  const NetworkPacketDrop({super.gate, super.throttle});
}

/// The server accepts and caches the response, but the client times out.
final class NetworkTimeoutAfterAccept<T> extends NetworkOutcome<T> {
  const NetworkTimeoutAfterAccept(this.value, {super.gate, super.throttle});

  final T value;
}

/// A manually released outcome useful for deterministic out-of-order calls.
final class NetworkOutOfOrder<T> extends NetworkOutcome<T> {
  const NetworkOutOfOrder(this.value, {required CompleterGate release})
    : super(gate: release);

  final T value;
}

final class RecordedCall<Request> {
  const RecordedCall({
    required this.request,
    required this.idempotencyKey,
    required this.payloadBytes,
  });

  final Request request;
  final String idempotencyKey;
  final int payloadBytes;
}

/// Records call multisets, idempotency keys, commits, and peak concurrency.
final class CallRecorder<Request> {
  final List<RecordedCall<Request>> calls = <RecordedCall<Request>>[];
  final Map<String, int> attemptsByKey = <String, int>{};
  final Map<String, int> commitsByKey = <String, int>{};
  int active = 0;
  int maxConcurrency = 0;

  void enter(Request request, String key, int bytes) {
    calls.add(
      RecordedCall<Request>(
        request: request,
        idempotencyKey: key,
        payloadBytes: bytes,
      ),
    );
    attemptsByKey.update(key, (value) => value + 1, ifAbsent: () => 1);
    active++;
    if (active > maxConcurrency) maxConcurrency = active;
  }

  void leave() => active--;

  void commitOnce(String key) {
    commitsByKey.putIfAbsent(key, () => 1);
  }
}

/// Generic deterministic network endpoint with server-side idempotency cache.
final class DeterministicNetwork<Request, Response> {
  DeterministicNetwork({
    Iterable<NetworkOutcome<Response>> outcomes = const [],
    CallRecorder<Request>? recorder,
  }) : _outcomes = List<NetworkOutcome<Response>>.from(outcomes),
       recorder = recorder ?? CallRecorder<Request>();

  final List<NetworkOutcome<Response>> _outcomes;
  final Map<String, Response> _accepted = <String, Response>{};
  final CallRecorder<Request> recorder;

  void add(NetworkOutcome<Response> outcome) => _outcomes.add(outcome);

  Future<Response> send({
    required Request request,
    required String idempotencyKey,
    required int payloadBytes,
  }) async {
    recorder.enter(request, idempotencyKey, payloadBytes);
    try {
      if (_accepted.containsKey(idempotencyKey)) {
        return _accepted[idempotencyKey] as Response;
      }
      if (_outcomes.isEmpty) {
        throw StateError('No network outcome remains for $request.');
      }
      final outcome = _outcomes.removeAt(0);
      await outcome.throttle?.consume(payloadBytes);
      await outcome.gate?.wait();
      return switch (outcome) {
        NetworkSuccess<Response>(:final value) => _accept(
          idempotencyKey,
          value,
        ),
        NetworkOutOfOrder<Response>(:final value) => _accept(
          idempotencyKey,
          value,
        ),
        NetworkPacketDrop<Response>() => throw const SocketException(
          'scripted packet drop',
        ),
        NetworkTimeoutAfterAccept<Response>(:final value) => () {
          _accept(idempotencyKey, value);
          throw TimeoutException('response lost after accept');
        }(),
      };
    } finally {
      recorder.leave();
    }
  }

  Response _accept(String key, Response value) {
    _accepted[key] = value;
    recorder.commitOnce(key);
    return value;
  }
}

final class ConnectivityHarness {
  ConnectivityHarness({this.online = false});

  bool online;
  ConnectivityResult carrier = ConnectivityResult.none;
  final StreamController<List<ConnectivityResult>> controller =
      StreamController<List<ConnectivityResult>>.broadcast(sync: true);

  Stream<List<ConnectivityResult>> get stream => controller.stream;
  Future<bool> isOnline() async => online;

  void emitOffline() {
    online = false;
    carrier = ConnectivityResult.none;
    controller.add(const <ConnectivityResult>[ConnectivityResult.none]);
  }

  void emitWifi({bool internetReachable = true}) {
    online = internetReachable;
    carrier = ConnectivityResult.wifi;
    controller.add(const <ConnectivityResult>[ConnectivityResult.wifi]);
  }

  void emitMobile({bool internetReachable = true}) {
    online = internetReachable;
    carrier = ConnectivityResult.mobile;
    controller.add(const <ConnectivityResult>[ConnectivityResult.mobile]);
  }

  void emitCaptivePortal() => emitWifi(internetReachable: false);

  void emitDuplicateWifiStorm([int count = 20]) {
    for (var index = 0; index < count; index++) {
      controller.add(const <ConnectivityResult>[ConnectivityResult.wifi]);
    }
  }

  void emitCarrierSequence() {
    emitOffline();
    emitWifi();
    emitMobile();
    emitOffline();
    emitWifi();
  }

  Future<void> dispose() => controller.close();
}

Future<void> pumpUntil(
  FutureOr<bool> Function() predicate, {
  int maxPumps = 80,
}) async {
  for (var index = 0; index < maxPumps; index++) {
    if (await predicate()) return;
    await pumpEventQueue();
  }
  throw TestFailure('Condition not reached after $maxPumps event pumps.');
}
