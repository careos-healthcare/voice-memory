import 'dart:convert';

/// Persisted metadata for an offline live-audio vault awaiting recovery upload.
class OfflineVaultManifest {
  const OfflineVaultManifest({
    required this.manifestId,
    required this.sessionId,
    required this.vaultPath,
    required this.frameCount,
    required this.durationSeconds,
    required this.createdAt,
    required this.idempotencyKey,
    required this.uploadState,
    this.recoveryAckId,
    this.lastError,
    this.recoverySecretBase64Url,
    this.serverRecoverable = true,
  });

  factory OfflineVaultManifest.fromJson(Map<String, dynamic> json) {
    return OfflineVaultManifest(
      manifestId: json['manifestId'] as String,
      sessionId: json['sessionId'] as String,
      vaultPath: json['vaultPath'] as String,
      frameCount: (json['frameCount'] as num?)?.toInt() ?? 0,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 1,
      createdAt: DateTime.parse(json['createdAt'] as String),
      idempotencyKey: json['idempotencyKey'] as String,
      uploadState: OfflineVaultUploadState.fromJson(
        json['uploadState'] as String? ?? 'pending',
      ),
      recoveryAckId: json['recoveryAckId'] as String?,
      lastError: json['lastError'] as String?,
      recoverySecretBase64Url: json['recoverySecretBase64Url'] as String?,
      serverRecoverable: json['serverRecoverable'] as bool? ?? true,
    );
  }

  final String manifestId;
  final String sessionId;
  final String vaultPath;
  final int frameCount;
  final int durationSeconds;
  final DateTime createdAt;
  final String idempotencyKey;
  final OfflineVaultUploadState uploadState;
  final String? recoveryAckId;
  final String? lastError;
  final String? recoverySecretBase64Url;
  final bool serverRecoverable;

  bool get requiresInlineRecoverySecret => sessionId.startsWith('offline_');

  List<int>? get recoverySecretKeyBytes {
    final encoded = recoverySecretBase64Url;
    if (encoded == null || encoded.isEmpty) {
      return null;
    }
    try {
      final bytes = base64Url.decode(encoded);
      return bytes.length == 32 ? bytes : null;
    } catch (_, stackTrace) {
      return null;
    }
  }

  static String? encodeRecoverySecretBase64Url(List<int>? bytes) {
    if (bytes == null || bytes.length != 32) {
      return null;
    }
    return base64Url.encode(bytes);
  }

  static bool isServerRecoverable({
    required String sessionId,
    List<int>? recoverySecretKeyBytes,
  }) {
    if (!sessionId.startsWith('offline_')) {
      return true;
    }
    return encodeRecoverySecretBase64Url(recoverySecretKeyBytes) != null;
  }

  bool get isPending =>
      uploadState == OfflineVaultUploadState.pending ||
      uploadState == OfflineVaultUploadState.failed;

  Map<String, dynamic> toJson() => {
    'manifestId': manifestId,
    'sessionId': sessionId,
    'vaultPath': vaultPath,
    'frameCount': frameCount,
    'durationSeconds': durationSeconds,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'idempotencyKey': idempotencyKey,
    'uploadState': uploadState.name,
    if (recoveryAckId != null) 'recoveryAckId': recoveryAckId,
    if (lastError != null) 'lastError': lastError,
    if (recoverySecretBase64Url != null)
      'recoverySecretBase64Url': recoverySecretBase64Url,
    'serverRecoverable': serverRecoverable,
  };

  OfflineVaultManifest copyWith({
    String? vaultPath,
    int? frameCount,
    int? durationSeconds,
    OfflineVaultUploadState? uploadState,
    String? recoveryAckId,
    String? lastError,
    String? recoverySecretBase64Url,
    bool? serverRecoverable,
  }) {
    return OfflineVaultManifest(
      manifestId: manifestId,
      sessionId: sessionId,
      vaultPath: vaultPath ?? this.vaultPath,
      frameCount: frameCount ?? this.frameCount,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      createdAt: createdAt,
      idempotencyKey: idempotencyKey,
      uploadState: uploadState ?? this.uploadState,
      recoveryAckId: recoveryAckId ?? this.recoveryAckId,
      lastError: lastError,
      recoverySecretBase64Url:
          recoverySecretBase64Url ?? this.recoverySecretBase64Url,
      serverRecoverable: serverRecoverable ?? this.serverRecoverable,
    );
  }
}

enum OfflineVaultUploadState {
  pending,
  uploading,
  completed,
  failed;

  static OfflineVaultUploadState fromJson(String raw) {
    return OfflineVaultUploadState.values.firstWhere(
      (state) => state.name == raw,
      orElse: () => OfflineVaultUploadState.pending,
    );
  }
}

/// Server response for a recovered offline vault upload.
class VaultRecoveryServerResult {
  const VaultRecoveryServerResult({
    required this.recoveryAckId,
    required this.transcript,
    required this.reflectionJson,
    required this.durationSeconds,
    required this.duplicate,
    this.frameCount = 0,
  });

  factory VaultRecoveryServerResult.fromJson(Map<String, dynamic> json) {
    return VaultRecoveryServerResult(
      recoveryAckId: json['recoveryAckId'] as String,
      transcript: json['transcript'] as String,
      reflectionJson: Map<String, dynamic>.from(
        json['reflection'] as Map<String, dynamic>,
      ),
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 1,
      duplicate: json['duplicate'] == true,
      frameCount: (json['frameCount'] as num?)?.toInt() ?? 0,
    );
  }

  final String recoveryAckId;
  final String transcript;
  final Map<String, dynamic> reflectionJson;
  final int durationSeconds;
  final bool duplicate;
  final int frameCount;
}