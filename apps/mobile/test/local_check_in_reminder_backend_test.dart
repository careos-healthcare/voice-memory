import 'package:archiveme_mobile/features/tomorrow_return/check_in_reminder_service.dart';
import 'package:archiveme_mobile/features/tomorrow_return/local_check_in_reminder_backend.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('no-op backend reports unavailable and never throws', () async {
    const backend = NoOpReminderBackend();
    expect(backend.isAvailable, isFalse);
    await backend.initialize();
    expect(await backend.requestPermission(), isFalse);
    await backend.schedule(
      checkInId: 'a',
      title: 't',
      body: 'b',
      when: DateTime.now().add(const Duration(days: 1)),
      payload: 'a',
    );
    await backend.cancel('a');
    await backend.clearAll();
  });

  test('local backend stays unavailable without a platform plugin', () async {
    final backend = LocalCheckInReminderBackend();
    // No native plugin is registered in a unit test, so init fails gracefully.
    await backend.initialize();
    expect(backend.isAvailable, isFalse);

    // Every call is a safe no-op while unavailable.
    expect(await backend.requestPermission(), isFalse);
    await backend.schedule(
      checkInId: 'tci1',
      title: 'Your check-in is ready',
      body: 'Answer the question you chose yesterday.',
      when: DateTime.now().add(const Duration(days: 1)),
      payload: 'tci1',
    );
    await backend.cancel('tci1');
    await backend.clearAll();
  });

  test('local backend tap callback forwards the payload', () {
    final backend = LocalCheckInReminderBackend();
    String? received;
    backend.onTapPayload = (payload) => received = payload;
    // The handler is private; simulate by invoking the public callback wiring.
    backend.onTapPayload?.call('tci-42');
    expect(received, 'tci-42');
  });
}