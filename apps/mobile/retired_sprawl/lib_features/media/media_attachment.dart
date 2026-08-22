import 'dart:collection';

enum MediaAttachmentKind {
  image;

  static MediaAttachmentKind fromJson(Object? value) {
    return values.where((item) => item.name == value).firstOrNull ?? image;
  }
}

/// Metadata for an encrypted, app-local media asset.
///
/// Paths point only to AES-GCM envelopes; plaintext media is never persisted.
class MediaAttachment {
  MediaAttachment({
    required this.id,
    required DateTime createdAt, String? localPath,
    String? encryptedFilePath,
    this.mimeType = 'image/jpeg',
    int? fileSize,
    String? encryptedHash,
    String? encryptedFileSha256,
    String caption = '',
    this.kind = MediaAttachmentKind.image,
    this.encryptedThumbnailPath = '',
    this.encryptedThumbnailSha256 = '',
    this.width = 0,
    this.height = 0,
  }) : localPath = localPath ?? encryptedFilePath ?? '',
       fileSize = fileSize ?? 0,
       encryptedHash = encryptedHash ?? encryptedFileSha256 ?? '',
       caption = _normalizeCaption(caption),
       createdAt = createdAt.toUtc();

  factory MediaAttachment.fromJson(Map<String, dynamic> json) {
    return MediaAttachment(
      id: json['id'] as String? ?? '',
      localPath:
          json['localPath'] as String? ??
          json['encryptedFilePath'] as String? ??
          '',
      mimeType: json['mimeType'] as String? ?? 'image/jpeg',
      fileSize: (json['fileSize'] as num?)?.toInt() ?? 0,
      encryptedHash:
          json['encryptedHash'] as String? ??
          json['encryptedFileSha256'] as String? ??
          '',
      caption: json['caption'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      kind: MediaAttachmentKind.fromJson(json['kind']),
      encryptedThumbnailPath: json['encryptedThumbnailPath'] as String? ?? '',
      encryptedThumbnailSha256:
          json['encryptedThumbnailSha256'] as String? ?? '',
      width: (json['width'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String localPath;
  final String mimeType;
  final int fileSize;
  final String encryptedHash;
  final String caption;
  final DateTime createdAt;
  final MediaAttachmentKind kind;
  final String encryptedThumbnailPath;
  final String encryptedThumbnailSha256;
  final int width;
  final int height;

  String get encryptedFilePath => localPath;
  String get encryptedFileSha256 => encryptedHash;

  MediaAttachment copyWith({String? caption, String? localPath}) =>
      MediaAttachment(
        id: id,
        localPath: localPath ?? this.localPath,
        mimeType: mimeType,
        fileSize: fileSize,
        encryptedHash: encryptedHash,
        caption: caption ?? this.caption,
        createdAt: createdAt,
        kind: kind,
        encryptedThumbnailPath: encryptedThumbnailPath,
        encryptedThumbnailSha256: encryptedThumbnailSha256,
        width: width,
        height: height,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'localPath': localPath,
    'mimeType': mimeType,
    'fileSize': fileSize,
    'encryptedHash': encryptedHash,
    'caption': caption,
    'createdAt': createdAt.toIso8601String(),
    'kind': kind.name,
    'encryptedThumbnailPath': encryptedThumbnailPath,
    'encryptedThumbnailSha256': encryptedThumbnailSha256,
    'width': width,
    'height': height,
  };

  Map<String, dynamic> toPortableJson() => {
    'id': id,
    'localPath': '',
    'mimeType': mimeType,
    'fileSize': 0,
    'encryptedHash': '',
    'caption': caption,
    'createdAt': createdAt.toIso8601String(),
    'kind': kind.name,
    'encryptedThumbnailPath': '',
    'encryptedThumbnailSha256': '',
    'width': width,
    'height': height,
  };
}

List<MediaAttachment> immutableMediaAttachments(
  Iterable<MediaAttachment> attachments,
) => UnmodifiableListView(List<MediaAttachment>.of(attachments));

String _normalizeCaption(String value) {
  final caption = value.trim();
  if (caption.length > 500) {
    throw ArgumentError.value(
      value,
      'caption',
      'must be at most 500 characters',
    );
  }
  return caption;
}