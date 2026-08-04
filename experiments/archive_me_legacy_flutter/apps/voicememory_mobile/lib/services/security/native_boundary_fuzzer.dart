import 'dart:convert';
import 'dart:typed_data';

enum NativeBoundaryKind { whisperCpp, llamaCpp, sqliteVec }

enum NativeFuzzVector {
  nullPointer,
  danglingPointer,
  oversizedBuffer,
  malformedUtf8,
}

final class NativeBoundaryViolation implements Exception {
  const NativeBoundaryViolation(this.message);
  final String message;

  @override
  String toString() => 'NativeBoundaryViolation: $message';
}

final class NativeFuzzFinding {
  const NativeFuzzFinding({
    required this.boundary,
    required this.vector,
    required this.rejected,
    required this.reason,
  });

  final NativeBoundaryKind boundary;
  final NativeFuzzVector vector;
  final bool rejected;
  final String reason;
}

/// Shared validation gate that rejects hostile values before a C-ABI call.
///
/// Arbitrary dangling pointers are never passed to native code. A C function
/// cannot portably prove that a non-null address is valid before dereferencing
/// it, so handle ownership is established in Dart and checked here.
final class NativeBoundaryContract {
  const NativeBoundaryContract._();

  static void requireOwnedPointer(
    int address, {
    required Set<int> ownedAddresses,
    int alignment = 8,
  }) {
    if (address == 0 ||
        address % alignment != 0 ||
        !ownedAddresses.contains(address)) {
      throw const NativeBoundaryViolation(
        'Native handle is null, misaligned, or not owned by this process.',
      );
    }
  }

  static void requireBoundedBytes(int length, {required int maximum}) {
    if (length < 0 || length > maximum) {
      throw NativeBoundaryViolation(
        'Native byte buffer exceeds the $maximum byte boundary.',
      );
    }
  }

  static String decodeStrictUtf8(Uint8List bytes, {required int maximum}) {
    requireBoundedBytes(bytes.length, maximum: maximum);
    try {
      return utf8.decode(bytes, allowMalformed: false);
    } on FormatException {
      throw const NativeBoundaryViolation(
        'Malformed UTF-8 was rejected before native dispatch.',
      );
    }
  }
}

/// Deterministic contract fuzzer used by the penetration audit suite.
///
/// It fuzzes the gates shared by native wrappers. Platform integration tests
/// may additionally run the real libraries in a separate OS process.
final class NativeBoundaryFuzzer {
  const NativeBoundaryFuzzer();

  List<NativeFuzzFinding> run() {
    final findings = <NativeFuzzFinding>[];
    for (final boundary in NativeBoundaryKind.values) {
      findings.add(
        _attempt(boundary, NativeFuzzVector.nullPointer, () {
          NativeBoundaryContract.requireOwnedPointer(
            0,
            ownedAddresses: const {0x1000},
          );
        }),
      );
      findings.add(
        _attempt(boundary, NativeFuzzVector.danglingPointer, () {
          NativeBoundaryContract.requireOwnedPointer(
            0x1008,
            ownedAddresses: const {0x1000},
          );
        }),
      );
      findings.add(
        _attempt(boundary, NativeFuzzVector.oversizedBuffer, () {
          NativeBoundaryContract.requireBoundedBytes(
            16 * 1024 * 1024 + 1,
            maximum: 16 * 1024 * 1024,
          );
        }),
      );
      findings.add(
        _attempt(boundary, NativeFuzzVector.malformedUtf8, () {
          NativeBoundaryContract.decodeStrictUtf8(
            Uint8List.fromList(const [0xc3, 0x28]),
            maximum: 64,
          );
        }),
      );
    }
    return List.unmodifiable(findings);
  }

  NativeFuzzFinding _attempt(
    NativeBoundaryKind boundary,
    NativeFuzzVector vector,
    void Function() operation,
  ) {
    try {
      operation();
      return NativeFuzzFinding(
        boundary: boundary,
        vector: vector,
        rejected: false,
        reason: 'Hostile value reached native dispatch.',
      );
    } on NativeBoundaryViolation catch (error) {
      return NativeFuzzFinding(
        boundary: boundary,
        vector: vector,
        rejected: true,
        reason: error.message,
      );
    }
  }
}
