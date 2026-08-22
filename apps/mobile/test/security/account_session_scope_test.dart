import 'package:archiveme_mobile/security/account_session_scope.dart';
import 'package:archiveme_mobile/storage/account_namespace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('account switch increments generation and cancels prior scope', () {
    final registry = AccountSessionRegistry.instance;
    final guest = registry.activate(
      namespace: AccountNamespace.guest,
      userId: null,
    );
    expect(guest.generation, greaterThan(0));

    final accountA = registry.activate(
      namespace: AccountNamespace.forUserId('user-a'),
      userId: 'user-a',
    );
    expect(accountA.generation, guest.generation + 1);
    expect(guest.isActive, isFalse);

    expect(
      () => guest.assertActive(registry.current),
      throwsA(isA<StaleAccountSessionException>()),
    );
  });

  test('stale async completion is rejected after switch to account B', () {
    final registry = AccountSessionRegistry.instance;
    final scopeA = registry.activate(
      namespace: AccountNamespace.forUserId('user-a'),
      userId: 'user-a',
    );
    registry.activate(
      namespace: AccountNamespace.forUserId('user-b'),
      userId: 'user-b',
    );
    expect(
      () => scopeA.assertActive(registry.current),
      throwsA(isA<StaleAccountSessionException>()),
    );
  });
}