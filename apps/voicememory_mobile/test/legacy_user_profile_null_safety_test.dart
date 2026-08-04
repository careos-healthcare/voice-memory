import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/models/session.dart';

void main() {
  group('legacy user profile parsing', () {
    test('missing and null user fields become safe empty values', () {
      final missing = UserSession.fromJson(const {});
      final nullProfile = UserSession.fromJson(const {
        'user': {'id': null, 'email': null},
        'signedInAt': null,
      });

      expect(missing.userId, isEmpty);
      expect(missing.email, isEmpty);
      expect(missing.signedInAt, isNull);
      expect(nullProfile.userId, isEmpty);
      expect(nullProfile.email, isEmpty);
      expect(nullProfile.signedInAt, isNull);
    });

    test('malformed legacy values do not throw or leak into UI strings', () {
      final session = UserSession.fromJson(const {
        'user': 'legacy-profile',
        'signedInAt': 123,
      });

      expect(session.userId, isEmpty);
      expect(session.email, isEmpty);
      expect(session.signedInAt, isNull);
    });

    test('valid profile values are trimmed and retained', () {
      final session = UserSession.fromJson(const {
        'user': {'id': ' user-1 ', 'email': ' person@example.com '},
        'signedInAt': '2026-07-29T12:00:00Z',
      });

      expect(session.userId, 'user-1');
      expect(session.email, 'person@example.com');
      expect(session.signedInAt, DateTime.utc(2026, 7, 29, 12));
    });
  });
}
