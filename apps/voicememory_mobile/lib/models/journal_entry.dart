import 'reflection.dart';
import 'sync_status.dart';

class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.createdAt,
    required this.transcript,
    required this.durationSeconds,
    required this.reflection,
    this.syncStatus = SyncStatus.localOnly,
    this.localAudioPath,
  });

  final String id;
  final DateTime createdAt;
  final String transcript;
  final int durationSeconds;
  final Reflection reflection;
  final SyncStatus syncStatus;
  final String? localAudioPath;

  String get reflectionSummary =>
      reflection.concreteObservation.isNotEmpty
          ? reflection.concreteObservation
          : reflection.exactLanguagePattern;

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    final reflectionJson =
        json['reflection'] as Map<String, dynamic>? ?? {};
    return JournalEntry(
      id: json['id'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now().toUtc(),
      transcript: json['transcript'] as String? ?? '',
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      reflection: Reflection.fromJson(reflectionJson),
      syncStatus: _parseSync(json['_syncStatus'] as String?),
      localAudioPath: json['localAudioPath'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'transcript': transcript,
        'durationSeconds': durationSeconds,
        'reflection': reflection.toJson(),
        '_syncStatus': _syncToString(syncStatus),
        if (localAudioPath != null) 'localAudioPath': localAudioPath,
      };

  static SyncStatus _parseSync(String? raw) {
    switch (raw) {
      case 'synced':
        return SyncStatus.synced;
      case 'pending':
        return SyncStatus.pendingUpload;
      default:
        return SyncStatus.localOnly;
    }
  }

  static String _syncToString(SyncStatus status) {
    switch (status) {
      case SyncStatus.synced:
        return 'synced';
      case SyncStatus.pendingUpload:
        return 'pending';
      default:
        return 'local';
    }
  }
}
