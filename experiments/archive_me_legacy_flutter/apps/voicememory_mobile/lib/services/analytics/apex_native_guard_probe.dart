import 'dart:ffi';
import 'dart:io';

final class ApexNativeGuardSnapshot {
  const ApexNativeGuardSnapshot({
    required this.available,
    required this.activeCount,
    required this.activeBytes,
    required this.invalidReleaseCount,
    required this.reason,
  });

  const ApexNativeGuardSnapshot.unavailable(this.reason)
    : available = false,
      activeCount = 0,
      activeBytes = 0,
      invalidReleaseCount = 0;

  final bool available;
  final int activeCount;
  final int activeBytes;
  final int invalidReleaseCount;
  final String reason;
}

abstract interface class ApexNativeGuardProbe {
  ApexNativeGuardSnapshot snapshot();
}

final class UnsupportedApexNativeGuardProbe implements ApexNativeGuardProbe {
  const UnsupportedApexNativeGuardProbe([
    this.reason = 'Native guard unavailable',
  ]);

  final String reason;

  @override
  ApexNativeGuardSnapshot snapshot() =>
      ApexNativeGuardSnapshot.unavailable(reason);
}

typedef _AbiNative = Uint32 Function();
typedef _AbiDart = int Function();
typedef _CounterNative = Uint64 Function(Int32);
typedef _CounterDart = int Function(int);
typedef _InvalidNative = Uint64 Function();
typedef _InvalidDart = int Function();

final class FfiApexNativeGuardProbe implements ApexNativeGuardProbe {
  FfiApexNativeGuardProbe._(DynamicLibrary library)
    : _abi = library.lookupFunction<_AbiNative, _AbiDart>(
        'apex_native_guard_abi_version',
      ),
      _count = library.lookupFunction<_CounterNative, _CounterDart>(
        'apex_native_guard_active_count',
      ),
      _bytes = library.lookupFunction<_CounterNative, _CounterDart>(
        'apex_native_guard_active_bytes',
      ),
      _invalid = library.lookupFunction<_InvalidNative, _InvalidDart>(
        'apex_native_guard_invalid_release_count',
      );

  factory FfiApexNativeGuardProbe.open({DynamicLibrary? library}) {
    final probe = FfiApexNativeGuardProbe._(library ?? _openPlatformLibrary());
    if (probe._abi() != 1) {
      throw UnsupportedError('Unsupported Apex native guard ABI.');
    }
    return probe;
  }

  final _AbiDart _abi;
  final _CounterDart _count;
  final _CounterDart _bytes;
  final _InvalidDart _invalid;

  @override
  ApexNativeGuardSnapshot snapshot() {
    var count = 0;
    var bytes = 0;
    for (var kind = 0; kind < 2; kind++) {
      count += _count(kind);
      bytes += _bytes(kind);
    }
    return ApexNativeGuardSnapshot(
      available: true,
      activeCount: count,
      activeBytes: bytes,
      invalidReleaseCount: _invalid(),
      reason: '',
    );
  }

  static DynamicLibrary _openPlatformLibrary() {
    final override = Platform.environment['ARCHIVEME_LLAMA_LIBRARY'];
    if (override != null && override.isNotEmpty) {
      return DynamicLibrary.open(override);
    }
    if (Platform.isIOS || Platform.isMacOS) return DynamicLibrary.process();
    if (Platform.isAndroid) return DynamicLibrary.open('libllama_mobile.so');
    throw UnsupportedError(
      'Apex native guard is not packaged on this platform.',
    );
  }
}

ApexNativeGuardProbe createPlatformApexNativeGuardProbe() {
  try {
    return FfiApexNativeGuardProbe.open();
  } on Object catch (error) {
    return UnsupportedApexNativeGuardProbe('$error');
  }
}
