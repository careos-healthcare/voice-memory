import 'package:archiveme_mobile/features/settings/services/sync_management_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local sync stays on until the purge response is 200', () async {
    var cleared = false;
    final service = SyncManagementService();

    final refused = await service.turnOffSyncAndDeleteServerCopy(
      sendPurge: () async => 500,
      onPurged: () async => cleared = true,
    );
    expect(refused, isFalse);
    expect(cleared, isFalse);

    final accepted = await service.turnOffSyncAndDeleteServerCopy(
      sendPurge: () async => 200,
      onPurged: () async => cleared = true,
    );
    expect(accepted, isTrue);
    expect(cleared, isTrue);
  });

  test('the purge request carries the session token', () {
    expect(
      bearerFromSessionCookie('vm_session=abc123; Path=/'),
      'abc123',
    );
    expect(bearerFromSessionCookie(null), isNull);
  });
}
