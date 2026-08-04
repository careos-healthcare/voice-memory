enum LlamaModelStatus {
  notConfigured,
  notOptedIn,
  checkingStorage,
  waitingForWifi,
  insufficientStorage,
  queued,
  downloading,
  paused,
  verifying,
  installed,
  failed,
}

enum LlamaModelFailure {
  storageProbe,
  insufficientStorage,
  enqueue,
  download,
  expectedSizeMismatch,
  checksumMismatch,
  fileSystem,
}

final class LlamaModelState {
  const LlamaModelState({
    required this.status,
    required this.optedIn,
    required this.userPaused,
    required this.progress,
    required this.downloadedBytes,
    this.taskId,
    this.catalogRevision,
    this.failure,
    this.installedPath,
    this.verifiedSha256,
    this.installedAt,
  });

  static const schemaVersion = 1;

  final LlamaModelStatus status;
  final bool optedIn;
  final bool userPaused;
  final double progress;
  final int downloadedBytes;
  final String? taskId;
  final String? catalogRevision;
  final LlamaModelFailure? failure;
  final String? installedPath;
  final String? verifiedSha256;
  final DateTime? installedAt;

  factory LlamaModelState.fromJson(Map<String, dynamic> json) {
    final statusName = json['status'];
    final failureName = json['failure'];
    return LlamaModelState(
      status: LlamaModelStatus.values.firstWhere(
        (value) => value.name == statusName,
        orElse: () => LlamaModelStatus.notOptedIn,
      ),
      optedIn: json['optedIn'] == true,
      userPaused: json['userPaused'] == true,
      progress: ((json['progress'] as num?)?.toDouble() ?? 0).clamp(0, 1),
      downloadedBytes: (json['downloadedBytes'] as num?)?.toInt() ?? 0,
      taskId: json['taskId'] as String?,
      catalogRevision: json['catalogRevision'] as String?,
      failure: LlamaModelFailure.values.cast<LlamaModelFailure?>().firstWhere(
        (value) => value?.name == failureName,
        orElse: () => null,
      ),
      installedPath: json['installedPath'] as String?,
      verifiedSha256: json['verifiedSha256'] as String?,
      installedAt: DateTime.tryParse('${json['installedAt'] ?? ''}'),
    );
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'status': status.name,
    'optedIn': optedIn,
    'userPaused': userPaused,
    'progress': progress,
    'downloadedBytes': downloadedBytes,
    'taskId': taskId,
    'catalogRevision': catalogRevision,
    'failure': failure?.name,
    'installedPath': installedPath,
    'verifiedSha256': verifiedSha256,
    'installedAt': installedAt?.toUtc().toIso8601String(),
  };

  LlamaModelState copyWith({
    LlamaModelStatus? status,
    bool? optedIn,
    bool? userPaused,
    double? progress,
    int? downloadedBytes,
    String? taskId,
    String? catalogRevision,
    LlamaModelFailure? failure,
    String? installedPath,
    String? verifiedSha256,
    DateTime? installedAt,
    bool clearFailure = false,
    bool clearInstallation = false,
  }) => LlamaModelState(
    status: status ?? this.status,
    optedIn: optedIn ?? this.optedIn,
    userPaused: userPaused ?? this.userPaused,
    progress: progress ?? this.progress,
    downloadedBytes: downloadedBytes ?? this.downloadedBytes,
    taskId: taskId ?? this.taskId,
    catalogRevision: catalogRevision ?? this.catalogRevision,
    failure: clearFailure ? null : (failure ?? this.failure),
    installedPath: clearInstallation
        ? null
        : (installedPath ?? this.installedPath),
    verifiedSha256: clearInstallation
        ? null
        : (verifiedSha256 ?? this.verifiedSha256),
    installedAt: clearInstallation ? null : (installedAt ?? this.installedAt),
  );
}

typedef LlamaModelSnapshot = LlamaModelState;
