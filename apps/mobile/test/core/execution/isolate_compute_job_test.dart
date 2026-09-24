import 'package:archiveme_mobile/core/execution/cancel_token.dart';
import 'package:archiveme_mobile/core/execution/isolate_compute_job.dart';
import 'package:flutter_test/flutter_test.dart';

int _double(int value) => value * 2;

void main() {
  tearDown(() {
    IsolateComputeJob.debugForceInline = false;
    IsolateJobTrace.reset();
    IsolateJobThrottle.shared.reset();
    IsolateJobThrottle.embedding.reset();
    IsolateJobThrottle.llm.reset();
  });

  test('Isolate.run ranks sendable work off the current isolate', () async {
    IsolateJobTrace.captureEvents = true;

    final result = await IsolateComputeJob.run<int, int>(
      label: 'test.double',
      payload: 21,
      computeFn: _double,
    );

    expect(result, 42);
    expect(IsolateJobTrace.events, isNotEmpty);
    expect(IsolateJobTrace.events.single.label, 'test.double');
    expect(IsolateJobTrace.events.single.duration, isNot(Duration.zero));
  });

  test('throttle serializes jobs at the cap', () async {
    final throttle = IsolateJobThrottle(maxConcurrent: 1);
    var peak = 0;
    var inFlight = 0;

    Future<void> hold(int millis) {
      return throttle.run(() async {
        inFlight++;
        if (inFlight > peak) peak = inFlight;
        await Future<void>.delayed(Duration(milliseconds: millis));
        inFlight--;
      });
    }

    await Future.wait([hold(20), hold(20), hold(20)]);
    expect(peak, 1);
  });

  test('cancelled token is refused before the isolate starts', () async {
    final token = ExecutionCancelToken()..cancel();

    expect(
      () => IsolateComputeJob.run<int, int>(
        label: 'test.cancelled',
        payload: 1,
        computeFn: _double,
        cancelToken: token,
      ),
      throwsA(isA<ExecutionCancelledException>()),
    );
  });
}
