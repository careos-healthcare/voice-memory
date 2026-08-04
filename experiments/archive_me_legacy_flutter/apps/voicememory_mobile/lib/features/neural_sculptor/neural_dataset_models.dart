import 'dart:convert';
import 'dart:io';

final class NeuralDatasetRecord {
  const NeuralDatasetRecord({
    required this.id,
    required this.instruction,
    required this.response,
    required this.provenanceId,
    required this.tokenEstimate,
    required this.sourceKinds,
  });

  final String id;
  final String instruction;
  final String response;
  final String provenanceId;
  final int tokenEstimate;
  final List<String> sourceKinds;

  Map<String, dynamic> toJson() => {
    'id': id,
    'instruction': instruction,
    'response': response,
    'provenanceId': provenanceId,
    'tokenEstimate': tokenEstimate,
    'sourceKinds': sourceKinds,
  };

  factory NeuralDatasetRecord.fromJson(Map<String, dynamic> json) =>
      NeuralDatasetRecord(
        id: json['id'] as String? ?? '',
        instruction: json['instruction'] as String? ?? '',
        response: json['response'] as String? ?? '',
        provenanceId: json['provenanceId'] as String? ?? '',
        tokenEstimate: (json['tokenEstimate'] as num?)?.toInt() ?? 0,
        sourceKinds: (json['sourceKinds'] as List? ?? const [])
            .whereType<String>()
            .toList(growable: false),
      );

  String toJsonLine() =>
      jsonEncode({'instruction': instruction, 'response': response});
}

final class NeuralDatasetManifest {
  const NeuralDatasetManifest({
    required this.id,
    required this.createdAt,
    required this.records,
    required this.selectedClusterIds,
    required this.tokenCount,
    required this.pseudonymized,
  });

  final String id;
  final DateTime createdAt;
  final List<NeuralDatasetRecord> records;
  final List<String> selectedClusterIds;
  final int tokenCount;
  final bool pseudonymized;

  int get recordCount => records.length;

  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'id': id,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'records': records.map((record) => record.toJson()).toList(),
    'selectedClusterIds': selectedClusterIds,
    'tokenCount': tokenCount,
    'pseudonymized': pseudonymized,
  };

  factory NeuralDatasetManifest.fromJson(
    Map<String, dynamic> json,
  ) => NeuralDatasetManifest(
    id: json['id'] as String? ?? '',
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '')?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    records: (json['records'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (record) =>
              NeuralDatasetRecord.fromJson(Map<String, dynamic>.from(record)),
        )
        .toList(growable: false),
    selectedClusterIds: (json['selectedClusterIds'] as List? ?? const [])
        .whereType<String>()
        .toList(growable: false),
    tokenCount: (json['tokenCount'] as num?)?.toInt() ?? 0,
    pseudonymized: json['pseudonymized'] == true,
  );
}

final class MaterializedNeuralDataset {
  MaterializedNeuralDataset({
    required this.file,
    required this.datasetId,
    required Future<void> Function() cleanup,
    // ignore: prefer_initializing_formals
  }) : _cleanup = cleanup;

  final File file;
  final String datasetId;
  final Future<void> Function() _cleanup;
  bool _cleaned = false;

  bool get isCleaned => _cleaned;

  Future<void> cleanup() async {
    if (_cleaned) return;
    _cleaned = true;
    await _cleanup();
  }
}
