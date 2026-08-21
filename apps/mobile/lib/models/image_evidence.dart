import 'package:archiveme_mobile/core/json/json_converters.dart';

/// Image evidence attached to a journal entry — caption is citeable in the ledger.
class ImageEvidence {
  const ImageEvidence({
    required this.evidenceId,
    required this.caption,
    required this.mimeType,
    required this.attachedAt,
    this.filename,
    this.byteLength,
    this.width,
    this.height,
    this.contentHash,
    this.source,
    this.localPath,
  });

  factory ImageEvidence.fromJson(Map<String, dynamic> json) {
    final attachedAtRaw = JsonConverters.stringOrEmpty(json['attachedAt']);
    return ImageEvidence(
      evidenceId: JsonConverters.stringOrEmpty(json['evidenceId']),
      caption: JsonConverters.stringOrEmpty(json['caption']),
      mimeType: JsonConverters.stringOrEmpty(json['mimeType']).isEmpty
          ? 'image/jpeg'
          : JsonConverters.stringOrEmpty(json['mimeType']),
      attachedAt: DateTime.tryParse(attachedAtRaw) ?? DateTime.now().toUtc(),
      filename: JsonConverters.nullableString(json['filename']),
      byteLength: JsonConverters.nullableInt(json['byteLength']),
      width: JsonConverters.nullableInt(json['width']),
      height: JsonConverters.nullableInt(json['height']),
      contentHash: JsonConverters.nullableString(json['contentHash']),
      source: JsonConverters.nullableString(json['source']),
      localPath: JsonConverters.nullableString(json['localPath']),
    );
  }

  final String evidenceId;
  final String caption;
  final String mimeType;
  final DateTime attachedAt;
  final String? filename;
  final int? byteLength;
  final int? width;
  final int? height;
  final String? contentHash;
  final String? source;

  /// Device-local blob path — never synced verbatim; metadata only crosses devices.
  final String? localPath;

  /// Text cited into fact_ledger — caption when present, otherwise a stable label.
  String get ledgerCitationText {
    final trimmed = caption.trim();
    if (trimmed.isNotEmpty) return trimmed;
    return 'Image evidence (${mimeType.split('/').last})';
  }

  Map<String, dynamic> toJson() => {
        'evidenceId': evidenceId,
        'caption': caption,
        'mimeType': mimeType,
        'attachedAt': attachedAt.toIso8601String(),
        if (filename != null) 'filename': filename,
        if (byteLength != null) 'byteLength': byteLength,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        if (contentHash != null) 'contentHash': contentHash,
        if (source != null) 'source': source,
        if (localPath != null) 'localPath': localPath,
      };

  ImageEvidence copyWith({
    String? evidenceId,
    String? caption,
    String? mimeType,
    DateTime? attachedAt,
    String? filename,
    int? byteLength,
    int? width,
    int? height,
    String? contentHash,
    String? source,
    String? localPath,
  }) {
    return ImageEvidence(
      evidenceId: evidenceId ?? this.evidenceId,
      caption: caption ?? this.caption,
      mimeType: mimeType ?? this.mimeType,
      attachedAt: attachedAt ?? this.attachedAt,
      filename: filename ?? this.filename,
      byteLength: byteLength ?? this.byteLength,
      width: width ?? this.width,
      height: height ?? this.height,
      contentHash: contentHash ?? this.contentHash,
      source: source ?? this.source,
      localPath: localPath ?? this.localPath,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageEvidence &&
          other.evidenceId == evidenceId &&
          other.caption == caption &&
          other.mimeType == mimeType &&
          other.attachedAt == attachedAt &&
          other.filename == filename &&
          other.byteLength == byteLength &&
          other.width == width &&
          other.height == height &&
          other.contentHash == contentHash &&
          other.source == source &&
          other.localPath == localPath;

  @override
  int get hashCode => Object.hash(
        evidenceId,
        caption,
        mimeType,
        attachedAt,
        filename,
        byteLength,
        width,
        height,
        contentHash,
        source,
        localPath,
      );
}
