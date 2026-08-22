import 'package:archiveme_mobile/security/user_content_safety.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sanitizePlainText', () {
    test('strips null bytes and control characters', () {
      expect(
        UserContentSafety.sanitizePlainText('hello\x00world'),
        'helloworld',
      );
    });

    test('preserves normal emotional language', () {
      const input = 'I feel overwhelmed and scared about tomorrow.';
      expect(UserContentSafety.sanitizePlainText(input), input);
    });

    test('caps extremely long text', () {
      final long = 'a' * (UserContentSafety.maxPlainTextChars + 100);
      expect(
        UserContentSafety.sanitizePlainText(long).length,
        UserContentSafety.maxPlainTextChars,
      );
    });
  });

  group('safeSnippet', () {
    test('script tag stays plain text', () {
      const input = '<script>alert(1)</script>';
      expect(UserContentSafety.safeSnippet(input), input);
    });

    test('markdown link is not interpreted', () {
      const input = '[click me](http://evil.example)';
      expect(UserContentSafety.safeSnippet(input), input);
    });

    test('caps long preview input', () {
      final long = 'word ' * 80;
      final snippet = UserContentSafety.safeSnippet(long, maxChars: 40);
      expect(snippet.length, lessThanOrEqualTo(41));
      expect(snippet.endsWith('…'), isTrue);
    });
  });

  group('secret detection', () {
    test('flags likely API keys', () {
      expect(
        UserContentSafety.containsPossibleSecret(
          'my key sk-abcdefghijklmnopqrstuvwxyz',
        ),
        isTrue,
      );
    });

    test('redacts secret-like strings', () {
      const input = 'token=sk-abcdefghijklmnopqrstuvwxyz';
      final redacted = UserContentSafety.redactSecrets(input);
      expect(redacted, contains('[REDACTED_SECRET]'));
      expect(redacted, isNot(contains('sk-abc')));
    });
  });

  group('privacyHash', () {
    test('does not expose full reflection text', () {
      const privateText = 'This is my secret journal entry about grief.';
      final hash = UserContentSafety.privacyHash(privateText);
      expect(hash.length, lessThan(privateText.length));
      expect(hash, isNot(contains('grief')));
    });
  });
}