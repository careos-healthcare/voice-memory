import 'package:archiveme_mobile/services/journal_ownership_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const guard = JournalOwnershipGuard();

  group('reconcile', () {
    test(
      'claims an unowned device journal for the first account that signs in',
      () {
        final result = guard.reconcile(
          storedOwnerKey: null,
          migrationPending: false,
          signedInUserId: 'user-a',
        );

        expect(result.ownerKey, 'user-a');
        expect(result.migrationPending, isFalse);
      },
    );

    test('same account signing back in does not trigger a migration', () {
      final result = guard.reconcile(
        storedOwnerKey: 'user-a',
        migrationPending: false,
        signedInUserId: 'user-a',
      );

      expect(result.ownerKey, 'user-a');
      expect(result.migrationPending, isFalse);
    });

    test('a different account signing in flags migration pending', () {
      final result = guard.reconcile(
        storedOwnerKey: 'user-a',
        migrationPending: false,
        signedInUserId: 'user-b',
      );

      expect(result.ownerKey, 'user-b');
      expect(result.migrationPending, isTrue);
    });

    test(
      'migration-pending state stays sticky even if the second account signs back in',
      () {
        final result = guard.reconcile(
          storedOwnerKey: 'user-b',
          migrationPending: true,
          signedInUserId: 'user-b',
        );

        expect(result.ownerKey, 'user-b');
        expect(result.migrationPending, isTrue);
      },
    );
  });

  group('isEligibleForSync', () {
    test('entries owned by the current account are always eligible', () {
      expect(
        guard.isEligibleForSync(
          entryOwnerKey: 'user-a',
          currentUserId: 'user-a',
          migrationPending: false,
        ),
        isTrue,
      );
      expect(
        guard.isEligibleForSync(
          entryOwnerKey: 'user-a',
          currentUserId: 'user-a',
          migrationPending: true,
        ),
        isTrue,
      );
    });

    test(
      'unowned legacy entries sync normally when no account switch has happened',
      () {
        expect(
          guard.isEligibleForSync(
            entryOwnerKey: null,
            currentUserId: 'user-a',
            migrationPending: false,
          ),
          isTrue,
        );
      },
    );

    test('unowned entries are blocked once an account switch is detected', () {
      expect(
        guard.isEligibleForSync(
          entryOwnerKey: null,
          currentUserId: 'user-b',
          migrationPending: true,
        ),
        isFalse,
      );
    });

    test(
      "a different account's entries are never eligible, switch or not",
      () {
        expect(
          guard.isEligibleForSync(
            entryOwnerKey: 'user-a',
            currentUserId: 'user-b',
            migrationPending: false,
          ),
          isFalse,
        );
        expect(
          guard.isEligibleForSync(
            entryOwnerKey: 'user-a',
            currentUserId: 'user-b',
            migrationPending: true,
          ),
          isFalse,
        );
      },
    );

    test('nothing is eligible with no current account', () {
      expect(
        guard.isEligibleForSync(
          entryOwnerKey: null,
          currentUserId: '',
          migrationPending: false,
        ),
        isFalse,
      );
    });
  });
}