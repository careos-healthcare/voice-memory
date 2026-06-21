import 'package:meta/meta.dart';

import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import 'archive_activation_funnel_tracker.dart';

class ArchiveActivationFunnelStoreState {
  const ArchiveActivationFunnelStoreState({
    this.events = const [],
  });

  final List<ArchiveActivationFunnelEvent> events;

  Map<String, dynamic> toJson() => {
        'events': events.map((event) => event.toJson()).toList(),
      };

  static ArchiveActivationFunnelStoreState fromJson(
    Map<String, dynamic>? json,
  ) {
    if (json == null || json.isEmpty) {
      return const ArchiveActivationFunnelStoreState();
    }
    final rawEvents = json['events'];
    final events = <ArchiveActivationFunnelEvent>[];
    if (rawEvents is List) {
      for (final raw in rawEvents) {
        if (raw is Map<String, dynamic>) {
          final event = ArchiveActivationFunnelEvent.fromJson(raw);
          if (event != null) events.add(event);
        } else if (raw is Map) {
          final event = ArchiveActivationFunnelEvent.fromJson(
            raw.map((k, v) => MapEntry(k.toString(), v)),
          );
          if (event != null) events.add(event);
        }
      }
    }
    events.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return ArchiveActivationFunnelStoreState(events: events);
  }
}

class ArchiveActivationFunnelStore {
  ArchiveActivationFunnelStore(this._prefs);

  final MobilePrefsStore _prefs;
  static const _key = 'archiveActivationFunnel';

  Future<ArchiveActivationFunnelStoreState> _load() async {
    return ArchiveActivationFunnelStoreState.fromJson(
      await _prefs.readMap(_key),
    );
  }

  Future<void> _save(ArchiveActivationFunnelStoreState state) async {
    await _prefs.writeMap(_key, state.toJson());
  }

  Future<void> track(ArchiveActivationFunnelEvent event) async {
    final state = await _load();
    final events = List<ArchiveActivationFunnelEvent>.from(state.events);
    events.removeWhere((item) => item.id == event.id);
    events.add(event);
    events.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _save(ArchiveActivationFunnelStoreState(events: events));
  }

  Future<List<ArchiveActivationFunnelEvent>> all() async {
    return (await _load()).events;
  }

  Future<void> clear() async {
    await _prefs.writeMap(_key, {});
  }

  Future<ArchiveActivationFunnelSummary> summary() async {
    return ArchiveActivationFunnelSummaryResolver.summarize(await all());
  }

  Future<List<List<String>>> exportCsvRows() async {
    final events = await all();
    final rows = <List<String>>[
      ['createdAt', 'type', 'entryId', 'mapId', 'proofId', 'source', 'metadata'],
    ];
    for (final event in events) {
      rows.add([
        event.createdAt.toIso8601String(),
        event.type.name,
        event.entryId ?? '',
        event.mapId ?? '',
        event.proofId ?? '',
        event.source ?? '',
        _csvCell(_metadataCell(event.metadata)),
      ]);
    }
    return rows;
  }

  @visibleForTesting
  Future<void> reset() => clear();

  static String _metadataCell(Map<String, String> metadata) {
    if (metadata.isEmpty) return '';
    return metadata.entries.map((e) => '${e.key}=${e.value}').join(';');
  }

  static String _csvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    if (escaped.contains(',') || escaped.contains('\n') || escaped.contains('"')) {
      return '"$escaped"';
    }
    return escaped;
  }
}

extension ArchiveActivationFunnelStoreTracking on ArchiveActivationFunnelStore {
  Future<void> trackType(
    ArchiveActivationFunnelEventType type, {
    String? entryId,
    String? mapId,
    String? proofId,
    String? source,
    Map<String, String>? metadata,
    bool dedupeShownPerSession = true,
  }) {
    return ArchiveActivationFunnelCoordinator.track(
      persist: track,
      type: type,
      entryId: entryId,
      mapId: mapId,
      proofId: proofId,
      source: source,
      metadata: metadata,
      dedupeShownPerSession: dedupeShownPerSession,
    );
  }
}

abstract class ArchiveActivationFunnelTracking {
  ArchiveActivationFunnelTracking._();

  static Future<void> record({
    required ArchiveActivationFunnelEventType type,
    String? entryId,
    String? mapId,
    String? proofId,
    String? source,
    Map<String, String>? metadata,
    bool dedupeShownPerSession = true,
  }) async {
    if (!AppServices.isInitialized) return;
    await ArchiveActivationFunnelStore(AppServices.instance.prefs).trackType(
      type,
      entryId: entryId,
      mapId: mapId,
      proofId: proofId,
      source: source,
      metadata: metadata,
      dedupeShownPerSession: dedupeShownPerSession,
    );
  }

  static Future<void> trackRecordingStarted({
    required int entryCountBeforeSave,
    required bool onboardingActive,
    String? onboardingStep,
    bool hasReturnProof = false,
    String? source,
  }) async {
    if (hasReturnProof) {
      await record(
        type: ArchiveActivationFunnelEventType.returnRecordingStarted,
        source: source,
      );
      return;
    }
    final step = onboardingStep?.trim();
    ArchiveActivationFunnelEventType? type;
    if (step == 'recordSecondMoment' || entryCountBeforeSave == 1) {
      type = ArchiveActivationFunnelEventType.secondRecordingStarted;
    } else if (step == 'recordThirdMoment' || entryCountBeforeSave == 2) {
      type = ArchiveActivationFunnelEventType.thirdRecordingStarted;
    } else if (!onboardingActive &&
        (step == 'recordFirstMoment' || entryCountBeforeSave <= 0)) {
      type = ArchiveActivationFunnelEventType.firstRecordingStarted;
    }
    if (type != null) {
      await record(type: type, source: source ?? (onboardingActive ? 'onboarding' : 'record'));
    }
  }

  static Future<void> trackRecordingCompleted({
    required int entryCountAfterSave,
    String? entryId,
    String? source,
    bool isReturnProof = false,
  }) async {
    if (isReturnProof) {
      await record(
        type: ArchiveActivationFunnelEventType.returnRecordingCompleted,
        entryId: entryId,
        proofId: entryId,
        source: source,
      );
      return;
    }
    final type = switch (entryCountAfterSave) {
      1 => ArchiveActivationFunnelEventType.firstRecordingCompleted,
      2 => ArchiveActivationFunnelEventType.secondRecordingCompleted,
      3 => ArchiveActivationFunnelEventType.thirdRecordingCompleted,
      _ => null,
    };
    if (type != null) {
      await record(type: type, entryId: entryId, source: source);
    }
  }
}
