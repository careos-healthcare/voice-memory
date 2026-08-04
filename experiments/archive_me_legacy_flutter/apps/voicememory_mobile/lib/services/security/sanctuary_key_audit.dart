import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Fail-closed assertions used by the cryptographic penetration test suite.
///
/// The audit deliberately retains only labels and counters. It never copies
/// key material into its own long-lived state.
final class SanctuaryKeyAudit {
  SanctuaryKeyAudit({this.maximumAuditedFileBytes = 16 * 1024 * 1024});

  final int maximumAuditedFileBytes;
  final Map<String, int> _destroyedByLabel = {};

  Map<String, int> get destroyedByLabel => Map.unmodifiable(_destroyedByLabel);

  void observeDestroyedKey(String label, Uint8List bytes) {
    if (label.trim().isEmpty) {
      throw const SanctuaryKeyAuditViolation('Destroyed key label is empty.');
    }
    if (bytes.isEmpty || bytes.any((value) => value != 0)) {
      throw SanctuaryKeyAuditViolation(
        'Key "$label" was observable after its destruction boundary.',
      );
    }
    _destroyedByLabel.update(label, (count) => count + 1, ifAbsent: () => 1);
  }

  void requireDestruction(String label, {int minimumCount = 1}) {
    if ((_destroyedByLabel[label] ?? 0) < minimumCount) {
      throw SanctuaryKeyAuditViolation(
        'Expected at least $minimumCount destruction event(s) for "$label".',
      );
    }
  }

  Future<void> assertNoPlaintextSecrets({
    required Directory directory,
    Iterable<String> textSecrets = const [],
    Iterable<Uint8List> binarySecrets = const [],
  }) async {
    if (!await directory.exists()) return;
    final needles = <Uint8List>[];
    for (final secret in textSecrets) {
      if (secret.isEmpty) continue;
      needles.add(Uint8List.fromList(utf8.encode(secret)));
    }
    for (final secret in binarySecrets) {
      if (secret.isEmpty) continue;
      needles
        ..add(Uint8List.fromList(secret))
        ..add(Uint8List.fromList(utf8.encode(base64Encode(secret))));
    }
    if (needles.isEmpty) {
      throw const SanctuaryKeyAuditViolation(
        'At least one non-empty secret is required for a disk audit.',
      );
    }
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) continue;
      final length = await entity.length();
      if (length > maximumAuditedFileBytes) {
        throw SanctuaryKeyAuditViolation(
          'Refusing to skip oversized audit target: ${entity.path}.',
        );
      }
      final bytes = await entity.readAsBytes();
      try {
        for (final needle in needles) {
          if (_contains(bytes, needle)) {
            throw SanctuaryKeyAuditViolation(
              'Plaintext recovery material found in ${entity.path}.',
            );
          }
        }
      } finally {
        bytes.fillRange(0, bytes.length, 0);
      }
    }
  }

  static bool _contains(Uint8List haystack, Uint8List needle) {
    if (needle.length > haystack.length) return false;
    for (var start = 0; start <= haystack.length - needle.length; start++) {
      var matches = true;
      for (var offset = 0; offset < needle.length; offset++) {
        if (haystack[start + offset] != needle[offset]) {
          matches = false;
          break;
        }
      }
      if (matches) return true;
    }
    return false;
  }
}

final class SanctuaryKeyAuditViolation implements Exception {
  const SanctuaryKeyAuditViolation(this.message);

  final String message;

  @override
  String toString() => 'SanctuaryKeyAuditViolation: $message';
}
