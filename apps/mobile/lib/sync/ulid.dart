import 'dart:math';

const _crockford = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

/// Generates a lexicographically sortable ULID (26 Crockford base32 chars).
String generateUlid([DateTime? timestamp]) {
  final ms = (timestamp ?? DateTime.now().toUtc()).millisecondsSinceEpoch;
  final random = Random.secure();
  final buffer = StringBuffer();

  var time = ms;
  for (var i = 0; i < 10; i++) {
    buffer.write(_crockford[time % 32]);
    time ~/= 32;
  }

  for (var i = 0; i < 16; i++) {
    buffer.write(_crockford[random.nextInt(32)]);
  }

  return buffer.toString();
}

bool isValidUlid(String value) {
  if (value.length != 26) return false;
  for (var i = 0; i < value.length; i++) {
    if (!_crockford.contains(value[i].toUpperCase())) {
      return false;
    }
  }
  return true;
}