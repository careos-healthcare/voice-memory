// Public named parameters cannot expose private field names.
// ignore_for_file: prefer_initializing_formals

import '../../storage/mobile_prefs_store.dart';
import 'processing_preferences.dart';

/// Read side of the stored processing answers.
///
/// Callers take the reader so a coordinator can be built without any storage
/// at all, in which case every capture asks.
abstract interface class ProcessingPreferencesReader {
  Future<ProcessingPreferences> read();
}

/// Read and write side, as the settings surface needs it.
abstract interface class ProcessingPreferencesController
    implements ProcessingPreferencesReader {
  Future<ProcessingPreferences> setTranscription(
    TranscriptionPreference preference,
  );

  Future<ProcessingPreferences> setInterpretation(
    InterpretationPreference preference,
  );
}

/// Device-local, archive-scoped storage for the processing answers.
///
/// The payload lives in [MobilePrefsStore], which is backed by platform secure
/// storage and is never part of the journal sync payload. Answers are keyed by
/// archive id so signing into a different archive on the same device does not
/// inherit the previous owner's answers.
final class ProcessingPreferencesStore
    implements ProcessingPreferencesController {
  ProcessingPreferencesStore({
    required MobilePrefsStore Function() prefs,
    required String Function() archiveId,
  }) : _prefs = prefs,
       _archiveId = archiveId;

  static const storageKey = 'processingPreferencesV1';

  final MobilePrefsStore Function() _prefs;
  final String Function() _archiveId;

  String get _scope {
    final id = _archiveId().trim();
    return id.isEmpty ? 'local' : id;
  }

  @override
  Future<ProcessingPreferences> read() async {
    try {
      final all = await _prefs().readJsonMap(storageKey);
      final scoped = all?[_scope];
      if (scoped is Map) {
        return ProcessingPreferences.fromJson(
          Map<String, dynamic>.from(scoped),
        );
      }
      return ProcessingPreferences.askEveryTime;
    } on Object {
      // An unreadable answer must never be guessed at; asking is the safe
      // fallback because it cannot send anything on its own.
      return ProcessingPreferences.askEveryTime;
    }
  }

  @override
  Future<ProcessingPreferences> setTranscription(
    TranscriptionPreference preference,
  ) => _mutate((current) => current.copyWith(transcription: preference));

  @override
  Future<ProcessingPreferences> setInterpretation(
    InterpretationPreference preference,
  ) => _mutate((current) => current.copyWith(interpretation: preference));

  Future<ProcessingPreferences> write(ProcessingPreferences preferences) =>
      _mutate((_) => preferences);

  /// Drops this archive's answers, returning it to asking every time.
  Future<ProcessingPreferences> clear() =>
      _mutate((_) => ProcessingPreferences.askEveryTime);

  Future<ProcessingPreferences> _mutate(
    ProcessingPreferences Function(ProcessingPreferences current) transform,
  ) async {
    final scope = _scope;
    late ProcessingPreferences updated;
    await _prefs().updateMap(storageKey, (current) {
      final data = Map<String, dynamic>.from(current ?? const {});
      final existing = data[scope];
      updated = transform(
        existing is Map
            ? ProcessingPreferences.fromJson(
                Map<String, dynamic>.from(existing),
              )
            : ProcessingPreferences.askEveryTime,
      );
      data[scope] = updated.toJson();
      return data;
    });
    return updated;
  }
}

/// Fixed answers for tests and for callers that deliberately always ask.
final class FixedProcessingPreferences implements ProcessingPreferencesReader {
  const FixedProcessingPreferences([
    this.value = ProcessingPreferences.askEveryTime,
  ]);

  final ProcessingPreferences value;

  @override
  Future<ProcessingPreferences> read() async => value;
}

/// Memory-backed answers, for tests and for previewing the settings surface.
final class InMemoryProcessingPreferences
    implements ProcessingPreferencesController {
  InMemoryProcessingPreferences([
    this._value = ProcessingPreferences.askEveryTime,
  ]);

  ProcessingPreferences _value;

  @override
  Future<ProcessingPreferences> read() async => _value;

  @override
  Future<ProcessingPreferences> setTranscription(
    TranscriptionPreference preference,
  ) async => _value = _value.copyWith(transcription: preference);

  @override
  Future<ProcessingPreferences> setInterpretation(
    InterpretationPreference preference,
  ) async => _value = _value.copyWith(interpretation: preference);
}
