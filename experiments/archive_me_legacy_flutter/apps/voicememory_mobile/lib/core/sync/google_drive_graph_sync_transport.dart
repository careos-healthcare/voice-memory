import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/googleapis_auth.dart';
import 'package:http/http.dart' as http;

import 'encrypted_graph_sync_engine.dart';

enum GoogleDriveGraphSyncErrorCode {
  notConfigured,
  authorizationRequired,
  unsupportedTarget,
  notFound,
  retryable,
  payloadTooLarge,
  invalidPayload,
  apiFailure,
}

enum GoogleDriveGraphSyncAvailability {
  available,
  notConfigured,
  authorizationRequired,
  unavailable,
  unsupported,
  retryableError,
}

class GoogleDriveGraphSyncException
    extends EncryptedGraphSyncTransportException {
  const GoogleDriveGraphSyncException(this.code, super.message);

  final GoogleDriveGraphSyncErrorCode code;
}

class DriveAppDataDownload {
  const DriveAppDataDownload({required this.stream, this.length});

  final Stream<List<int>> stream;
  final int? length;
}

class DriveAppDataFile {
  const DriveAppDataFile({required this.id, this.modifiedTime});

  final String id;
  final DateTime? modifiedTime;
}

/// Narrow Drive appDataFolder API used by the transport and unit tests.
abstract interface class DriveAppDataClient {
  Future<List<DriveAppDataFile>> findFilesByName(String name);

  Future<void> createFile({
    required String name,
    required List<int> utf8Content,
  });

  Future<void> updateFile({
    required String fileId,
    required List<int> utf8Content,
  });

  Future<DriveAppDataDownload> downloadFile(String fileId);
}

typedef DriveAppDataClientFactory =
    DriveAppDataClient Function(AuthClient authClient);

/// Supplies a short-lived authenticated HTTP client.
///
/// Automatic uploads/downloads call only [authorizeNonInteractively].
abstract interface class GoogleDriveAuthorization {
  Future<AuthClient?> authorizeNonInteractively();

  Future<AuthClient> authorizeInteractively();
}

/// Production Google Sign-In v7 authorization.
///
/// Google Cloud setup:
/// * Enable Drive API and configure the OAuth consent screen.
/// * Register an Android OAuth client for the application ID and every release
///   signing certificate SHA-1/SHA-256 (including Play App Signing).
/// * Register a Web OAuth client and pass its client ID at build time with
///   `--dart-define=GOOGLE_DRIVE_SERVER_CLIENT_ID=...`.
///
/// Tokens are never persisted here; google_sign_in owns platform credentials.
class GoogleSignInDriveAuthorization implements GoogleDriveAuthorization {
  GoogleSignInDriveAuthorization({
    required this.serverClientId,
    GoogleSignIn? signIn,
  }) : _signIn = signIn ?? GoogleSignIn.instance;

  static const scopes = <String>[drive.DriveApi.driveAppdataScope];

  final String serverClientId;
  final GoogleSignIn _signIn;
  Future<void>? _initialization;

  Future<void> _initialize() {
    return _initialization ??= _signIn.initialize(
      serverClientId: serverClientId,
    );
  }

  @override
  Future<AuthClient?> authorizeNonInteractively() async {
    await _initialize();
    final attempt = _signIn.attemptLightweightAuthentication();
    final account = attempt == null ? null : await attempt;
    if (account == null) return null;
    final authorization = await account.authorizationClient
        .authorizationForScopes(scopes);
    return authorization?.authClient(scopes: scopes);
  }

  @override
  Future<AuthClient> authorizeInteractively() async {
    await _initialize();
    final account = await _signIn.authenticate(scopeHint: scopes);
    final authorization =
        await account.authorizationClient.authorizationForScopes(scopes) ??
        await account.authorizationClient.authorizeScopes(scopes);
    return authorization.authClient(scopes: scopes);
  }
}

class GoogleApisDriveAppDataClient implements DriveAppDataClient {
  GoogleApisDriveAppDataClient(AuthClient authClient)
    : _files = drive.DriveApi(authClient).files;

  static const _contentType = 'application/json; charset=utf-8';

  final drive.FilesResource _files;

  @override
  Future<List<DriveAppDataFile>> findFilesByName(String name) async {
    final escapedName = name.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
    final matches = <DriveAppDataFile>[];
    String? pageToken;
    do {
      final result = await _files.list(
        spaces: 'appDataFolder',
        q: "name = '$escapedName' and trashed = false",
        pageSize: 100,
        pageToken: pageToken,
        $fields: 'nextPageToken,files(id,modifiedTime)',
      );
      matches.addAll(
        (result.files ?? const <drive.File>[])
            .where((file) => file.id != null)
            .map(
              (file) => DriveAppDataFile(
                id: file.id!,
                modifiedTime: file.modifiedTime,
              ),
            ),
      );
      pageToken = result.nextPageToken;
    } while (pageToken != null && pageToken.isNotEmpty);
    return matches;
  }

  @override
  Future<void> createFile({
    required String name,
    required List<int> utf8Content,
  }) async {
    await _files.create(
      drive.File()
        ..name = name
        ..parents = const ['appDataFolder'],
      uploadMedia: drive.Media(
        Stream<List<int>>.value(utf8Content),
        utf8Content.length,
        contentType: _contentType,
      ),
    );
  }

  @override
  Future<DriveAppDataDownload> downloadFile(String fileId) async {
    final result = await _files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    );
    final media = result as drive.Media;
    return DriveAppDataDownload(stream: media.stream, length: media.length);
  }

  @override
  Future<void> updateFile({
    required String fileId,
    required List<int> utf8Content,
  }) async {
    await _files.update(
      drive.File(),
      fileId,
      uploadMedia: drive.Media(
        Stream<List<int>>.value(utf8Content),
        utf8Content.length,
        contentType: _contentType,
      ),
    );
  }
}

/// Android-only encrypted graph transport using Drive's hidden appDataFolder.
///
/// Upload/download never prompt. Call [authorizeInteractively] from an explicit
/// foreground user action before enabling sync.
class GoogleDriveGraphSyncTransport implements EncryptedGraphSyncTransport {
  GoogleDriveGraphSyncTransport({
    String serverClientId = const String.fromEnvironment(
      'GOOGLE_DRIVE_SERVER_CLIENT_ID',
    ),
    GoogleDriveAuthorization? authorization,
    DriveAppDataClientFactory? driveClientFactory,
    bool Function()? isAndroid,
    this.maxDownloadBytes = 16 * 1024 * 1024,
    this.maxUploadBytes = 16 * 1024 * 1024,
    this.operationTimeout = const Duration(seconds: 30),
  }) : _serverClientId = serverClientId.trim(),
       _authorization =
           authorization ??
           GoogleSignInDriveAuthorization(
             serverClientId: serverClientId.trim(),
           ),
       _driveClientFactory =
           driveClientFactory ?? GoogleApisDriveAppDataClient.new,
       _isAndroid = isAndroid ?? _platformIsAndroid;

  final String _serverClientId;
  final GoogleDriveAuthorization _authorization;
  final DriveAppDataClientFactory _driveClientFactory;
  final bool Function() _isAndroid;
  final int maxDownloadBytes;
  final int maxUploadBytes;
  final Duration operationTimeout;

  static bool _platformIsAndroid() => Platform.isAndroid;

  /// Maps a logical path to a deterministic, query-safe appDataFolder name.
  static String fileNameForPath(String path) {
    final digest = sha256.convert(utf8.encode(path));
    return 'archiveme-graph-v1-$digest.enc';
  }

  /// Performs the only flow allowed to show Google account/scope UI.
  Future<void> authorizeInteractively() async {
    _validateConfiguration();
    AuthClient? client;
    try {
      client = await _authorization.authorizeInteractively();
    } on Object catch (error) {
      throw _classifyAuthorizationFailure(error);
    } finally {
      client?.close();
    }
  }

  /// Probes configuration and cached authorization without presenting UI.
  Future<GoogleDriveGraphSyncAvailability> availability() async {
    AuthClient? client;
    try {
      _validateConfiguration();
      client = await _authorization.authorizeNonInteractively();
      return client == null
          ? GoogleDriveGraphSyncAvailability.authorizationRequired
          : GoogleDriveGraphSyncAvailability.available;
    } on Object catch (error) {
      final classified = error is GoogleDriveGraphSyncException
          ? error
          : _classifyFailure(error);
      return switch (classified.code) {
        GoogleDriveGraphSyncErrorCode.notConfigured =>
          GoogleDriveGraphSyncAvailability.notConfigured,
        GoogleDriveGraphSyncErrorCode.authorizationRequired =>
          GoogleDriveGraphSyncAvailability.authorizationRequired,
        GoogleDriveGraphSyncErrorCode.unsupportedTarget =>
          GoogleDriveGraphSyncAvailability.unsupported,
        GoogleDriveGraphSyncErrorCode.retryable =>
          GoogleDriveGraphSyncAvailability.retryableError,
        GoogleDriveGraphSyncErrorCode.notFound ||
        GoogleDriveGraphSyncErrorCode.payloadTooLarge ||
        GoogleDriveGraphSyncErrorCode.invalidPayload ||
        GoogleDriveGraphSyncErrorCode.apiFailure =>
          GoogleDriveGraphSyncAvailability.unavailable,
      };
    } finally {
      client?.close();
    }
  }

  @override
  Future<void> upload({
    required EncryptedGraphSyncTarget target,
    required String path,
    required String encryptedEnvelope,
  }) async {
    _validateTargetAndConfiguration(target);
    await _withDriveClient((client) async {
      final name = fileNameForPath(path);
      final content = utf8.encode(encryptedEnvelope);
      if (content.length > maxUploadBytes) {
        throw const GoogleDriveGraphSyncException(
          GoogleDriveGraphSyncErrorCode.payloadTooLarge,
          'The encrypted graph exceeds the upload size limit.',
        );
      }
      _validateEnvelope(encryptedEnvelope);
      final files = await client.findFilesByName(name);
      if (files.isEmpty) {
        await client.createFile(name: name, utf8Content: content);
      } else {
        await client.updateFile(
          fileId: _newestFile(files).id,
          utf8Content: content,
        );
      }
    });
  }

  @override
  Future<String> download({
    required EncryptedGraphSyncTarget target,
    required String path,
  }) async {
    _validateTargetAndConfiguration(target);
    return _withDriveClient((client) async {
      final files = await client.findFilesByName(fileNameForPath(path));
      if (files.isEmpty) {
        throw const GoogleDriveGraphSyncException(
          GoogleDriveGraphSyncErrorCode.notFound,
          'No encrypted graph exists in Google Drive app data.',
        );
      }
      final download = await client.downloadFile(_newestFile(files).id);
      if (download.length != null && download.length! > maxDownloadBytes) {
        throw const GoogleDriveGraphSyncException(
          GoogleDriveGraphSyncErrorCode.payloadTooLarge,
          'The encrypted graph exceeds the download size limit.',
        );
      }
      final bytes = <int>[];
      await for (final chunk in download.stream) {
        if (bytes.length + chunk.length > maxDownloadBytes) {
          throw const GoogleDriveGraphSyncException(
            GoogleDriveGraphSyncErrorCode.payloadTooLarge,
            'The encrypted graph exceeds the download size limit.',
          );
        }
        bytes.addAll(chunk);
      }
      try {
        final encoded = utf8.decode(bytes, allowMalformed: false);
        _validateEnvelope(encoded);
        return encoded;
      } on FormatException {
        throw const GoogleDriveGraphSyncException(
          GoogleDriveGraphSyncErrorCode.invalidPayload,
          'The encrypted graph is not valid UTF-8.',
        );
      }
    });
  }

  Future<T> _withDriveClient<T>(
    Future<T> Function(DriveAppDataClient client) action,
  ) async {
    AuthClient? authClient;
    try {
      authClient = await _authorization.authorizeNonInteractively();
      if (authClient == null) {
        throw const GoogleDriveGraphSyncException(
          GoogleDriveGraphSyncErrorCode.authorizationRequired,
          'Google Drive authorization requires a user action.',
        );
      }
      return await action(
        _driveClientFactory(authClient),
      ).timeout(operationTimeout);
    } on GoogleDriveGraphSyncException {
      rethrow;
    } on Object catch (error) {
      throw _classifyFailure(error);
    } finally {
      authClient?.close();
    }
  }

  void _validateTargetAndConfiguration(EncryptedGraphSyncTarget target) {
    if (target != EncryptedGraphSyncTarget.googleDrive) {
      throw const GoogleDriveGraphSyncException(
        GoogleDriveGraphSyncErrorCode.unsupportedTarget,
        'This transport supports only Google Drive.',
      );
    }
    _validateConfiguration();
  }

  void _validateConfiguration() {
    if (!_isAndroid()) {
      throw const GoogleDriveGraphSyncException(
        GoogleDriveGraphSyncErrorCode.unsupportedTarget,
        'Google Drive graph sync is supported only on Android.',
      );
    }
    if (_serverClientId.isEmpty) {
      throw const GoogleDriveGraphSyncException(
        GoogleDriveGraphSyncErrorCode.notConfigured,
        'Google Drive OAuth client configuration is missing.',
      );
    }
  }

  static DriveAppDataFile _newestFile(List<DriveAppDataFile> files) {
    final sorted = List<DriveAppDataFile>.of(files)
      ..sort((left, right) {
        final leftTime = left.modifiedTime;
        final rightTime = right.modifiedTime;
        if (leftTime != null && rightTime != null) {
          final byTime = rightTime.compareTo(leftTime);
          if (byTime != 0) return byTime;
        } else if (leftTime != null) {
          return -1;
        } else if (rightTime != null) {
          return 1;
        }
        return left.id.compareTo(right.id);
      });
    return sorted.first;
  }

  static void _validateEnvelope(String encoded) {
    try {
      EncryptedGraphSyncEnvelope.decode(encoded);
    } on EncryptedGraphSyncFormatException {
      throw const GoogleDriveGraphSyncException(
        GoogleDriveGraphSyncErrorCode.invalidPayload,
        'The encrypted graph envelope is malformed.',
      );
    }
  }

  static GoogleDriveGraphSyncException _classifyAuthorizationFailure(
    Object error,
  ) {
    if (error is GoogleSignInException) {
      switch (error.code) {
        case GoogleSignInExceptionCode.clientConfigurationError:
        case GoogleSignInExceptionCode.providerConfigurationError:
          return const GoogleDriveGraphSyncException(
            GoogleDriveGraphSyncErrorCode.notConfigured,
            'Google Drive OAuth client configuration is invalid.',
          );
        default:
          return const GoogleDriveGraphSyncException(
            GoogleDriveGraphSyncErrorCode.authorizationRequired,
            'Google Drive authorization requires a user action.',
          );
      }
    }
    return _classifyFailure(error);
  }

  static GoogleDriveGraphSyncException _classifyFailure(Object error) {
    if (error is GoogleSignInException) {
      return _classifyAuthorizationFailure(error);
    }
    if (error is drive.DetailedApiRequestError) {
      final status = error.status;
      if (status == 401 || status == 403) {
        return const GoogleDriveGraphSyncException(
          GoogleDriveGraphSyncErrorCode.authorizationRequired,
          'Google Drive authorization is no longer valid.',
        );
      }
      if (status == 404) {
        return const GoogleDriveGraphSyncException(
          GoogleDriveGraphSyncErrorCode.notFound,
          'The encrypted graph was not found in Google Drive.',
        );
      }
      if (status == 408 || status == 429 || (status != null && status >= 500)) {
        return const GoogleDriveGraphSyncException(
          GoogleDriveGraphSyncErrorCode.retryable,
          'Google Drive is temporarily unavailable.',
        );
      }
    }
    if (error is SocketException ||
        error is http.ClientException ||
        error is TimeoutException) {
      return const GoogleDriveGraphSyncException(
        GoogleDriveGraphSyncErrorCode.retryable,
        'Google Drive is temporarily unavailable.',
      );
    }
    return const GoogleDriveGraphSyncException(
      GoogleDriveGraphSyncErrorCode.apiFailure,
      'Google Drive app data operation failed.',
    );
  }
}
