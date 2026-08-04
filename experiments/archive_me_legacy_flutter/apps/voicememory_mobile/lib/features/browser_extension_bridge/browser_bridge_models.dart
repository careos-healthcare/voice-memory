import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

final class BrowserPairingInvitation {
  BrowserPairingInvitation({
    required this.endpoint,
    required this.token,
    required this.pin,
    required DateTime expiresAt,
    this.tlsCertificateFingerprint,
  }) : expiresAt = expiresAt.toUtc();

  final Uri endpoint;
  final String token;
  final String pin;
  final DateTime expiresAt;
  final String? tlsCertificateFingerprint;

  bool isValidAt(DateTime now) => expiresAt.isAfter(now.toUtc());

  String encode() => jsonEncode({
    'version': 1,
    'endpoint': endpoint.toString(),
    'token': token,
    'pin': pin,
    'expiresAt': expiresAt.toIso8601String(),
    if (tlsCertificateFingerprint != null)
      'tlsFingerprint': tlsCertificateFingerprint,
  });
}

final class TrustedBrowserExtension {
  TrustedBrowserExtension({
    required this.id,
    required this.name,
    required Uint8List publicKey,
    required Uint8List sessionKey,
    required DateTime pairedAt,
    required DateTime lastSeenAt,
    this.clipCount = 0,
  }) : publicKey = Uint8List.fromList(publicKey),
       sessionKey = Uint8List.fromList(sessionKey),
       pairedAt = pairedAt.toUtc(),
       lastSeenAt = lastSeenAt.toUtc();

  final String id;
  final String name;
  final Uint8List publicKey;
  final Uint8List sessionKey;
  final DateTime pairedAt;
  final DateTime lastSeenAt;
  final int clipCount;

  TrustedBrowserExtension copyWith({DateTime? lastSeenAt, int? clipCount}) =>
      TrustedBrowserExtension(
        id: id,
        name: name,
        publicKey: publicKey,
        sessionKey: sessionKey,
        pairedAt: pairedAt,
        lastSeenAt: lastSeenAt ?? this.lastSeenAt,
        clipCount: clipCount ?? this.clipCount,
      );

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'publicKey': base64Encode(publicKey),
    'sessionKey': base64Encode(sessionKey),
    'pairedAt': pairedAt.toIso8601String(),
    'lastSeenAt': lastSeenAt.toIso8601String(),
    'clipCount': clipCount,
  };

  factory TrustedBrowserExtension.fromJson(Map<String, dynamic> json) =>
      TrustedBrowserExtension(
        id: json['id'] as String,
        name: json['name'] as String,
        publicKey: base64Decode(json['publicKey'] as String),
        sessionKey: base64Decode(json['sessionKey'] as String),
        pairedAt: DateTime.parse(json['pairedAt'] as String),
        lastSeenAt: DateTime.parse(json['lastSeenAt'] as String),
        clipCount: (json['clipCount'] as num?)?.toInt() ?? 0,
      );
}

final class WebClipPayload {
  WebClipPayload({
    required this.url,
    required this.title,
    required this.content,
    required this.contentType,
    required DateTime capturedAt,
    this.selection,
    Iterable<String> highlights = const [],
    Map<String, String> metadata = const {},
    Uint8List? screenshot,
  }) : capturedAt = capturedAt.toUtc(),
       highlights = UnmodifiableListView(
         highlights
             .map((value) => value.trim())
             .where((value) => value.isNotEmpty),
       ),
       metadata = UnmodifiableMapView(Map<String, String>.from(metadata)),
       screenshot = screenshot == null ? null : Uint8List.fromList(screenshot);

  final Uri url;
  final String title;
  final String content;
  final String contentType;
  final DateTime capturedAt;
  final String? selection;
  final List<String> highlights;
  final Map<String, String> metadata;
  final Uint8List? screenshot;

  Map<String, Object?> toJson() => {
    'url': url.toString(),
    'title': title,
    'content': content,
    'contentType': contentType,
    'capturedAt': capturedAt.toIso8601String(),
    'selection': selection,
    'highlights': highlights,
    'metadata': metadata,
    'screenshot': screenshot == null ? null : base64Encode(screenshot!),
  };

  factory WebClipPayload.fromJson(Map<String, dynamic> json) {
    final uri = Uri.tryParse(json['url'] as String? ?? '');
    if (uri == null || !{'http', 'https'}.contains(uri.scheme)) {
      throw const FormatException('Clip URL must use HTTP or HTTPS.');
    }
    return WebClipPayload(
      url: uri,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      contentType: json['contentType'] as String? ?? 'text/html',
      capturedAt:
          DateTime.tryParse(json['capturedAt'] as String? ?? '') ??
          DateTime.now(),
      selection: json['selection'] as String?,
      highlights: (json['highlights'] as List? ?? const []).whereType<String>(),
      metadata: Map<String, String>.from(json['metadata'] as Map? ?? const {}),
      screenshot: json['screenshot'] is String
          ? base64Decode(json['screenshot'] as String)
          : null,
    );
  }
}

final class BrowserClipRecord {
  const BrowserClipRecord({
    required this.id,
    required this.extensionId,
    required this.payload,
    required this.chunkCount,
    required this.clusterIds,
  });

  final String id;
  final String extensionId;
  final WebClipPayload payload;
  final int chunkCount;
  final List<String> clusterIds;
}
