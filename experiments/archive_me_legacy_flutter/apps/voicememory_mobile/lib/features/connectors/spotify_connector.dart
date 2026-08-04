import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;

import '../../config/app_config.dart';
import '../../services/local_storage/encrypted_storage_engine.dart';
import '../../services/security/biometric_vault_service.dart';
import '../../storage/mobile_prefs_store.dart';
import 'external_data_adapters.dart';
import 'external_graph_service.dart';

class SpotifyCredential {
  const SpotifyCredential({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;

  Map<String, dynamic> toJson() => {
    'access': accessToken,
    'refresh': refreshToken,
    'expiresAt': expiresAt.toUtc().toIso8601String(),
  };

  factory SpotifyCredential.fromJson(Map<String, dynamic> json) =>
      SpotifyCredential(
        accessToken: '${json['access']}',
        refreshToken: '${json['refresh']}',
        expiresAt:
            DateTime.tryParse('${json['expiresAt']}') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
}

abstract interface class SpotifyCredentialStore {
  Future<SpotifyCredential?> read();
  Future<void> write(SpotifyCredential credential);
  Future<void> clear();
}

class BiometricSpotifyCredentialStore implements SpotifyCredentialStore {
  BiometricSpotifyCredentialStore({
    required this.vault,
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  static const _storageKey = 'vm_spotify_oauth_bundle_v1';
  final BiometricVaultService vault;
  final FlutterSecureStorage _storage;
  final EncryptedStorageEngine _encryption = EncryptedStorageEngine();

  @override
  Future<SpotifyCredential?> read() async {
    final encoded = await _storage.read(key: _storageKey);
    if (encoded == null) return null;
    return vault.withUnlockedKey((key) async {
      final envelope = jsonDecode(encoded);
      final cleartext = await _encryption.decrypt(
        Map<String, dynamic>.from(envelope as Map),
        keyBytes: key,
      );
      return SpotifyCredential.fromJson(
        Map<String, dynamic>.from(jsonDecode(utf8.decode(cleartext)) as Map),
      );
    });
  }

  @override
  Future<void> write(SpotifyCredential credential) =>
      vault.withUnlockedKey((key) async {
        final envelope = await _encryption.encrypt(
          utf8.encode(jsonEncode(credential.toJson())),
          keyBytes: key,
        );
        await _storage.write(key: _storageKey, value: jsonEncode(envelope));
      });

  @override
  Future<void> clear() => _storage.delete(key: _storageKey);
}

class MemorySpotifyCredentialStore implements SpotifyCredentialStore {
  SpotifyCredential? credential;

  @override
  Future<SpotifyCredential?> read() async => credential;

  @override
  Future<void> write(SpotifyCredential value) async => credential = value;

  @override
  Future<void> clear() async => credential = null;
}

abstract interface class SpotifyOAuthGateway {
  Future<SpotifyCredential> authorize();
  Future<SpotifyCredential> refresh(String refreshToken);
}

class SpotifyPkceOAuthService implements SpotifyOAuthGateway {
  SpotifyPkceOAuthService({
    required this.clientId,
    http.Client? client,
    Random? random,
  }) : _client = client ?? http.Client(),
       _random = random ?? Random.secure();

  final String clientId;
  final http.Client _client;
  final Random _random;
  static const _redirectUri = 'archiveme-spotify://callback';

  @override
  Future<SpotifyCredential> authorize() async {
    if (clientId.isEmpty) {
      throw StateError('SPOTIFY_CLIENT_ID is not configured.');
    }
    final verifier = _randomText(64);
    final state = _randomText(24);
    final digest = await Sha256().hash(utf8.encode(verifier));
    final challenge = base64UrlEncode(digest.bytes).replaceAll('=', '');
    final authorizeUri = Uri.https('accounts.spotify.com', '/authorize', {
      'response_type': 'code',
      'client_id': clientId,
      'redirect_uri': _redirectUri,
      'code_challenge_method': 'S256',
      'code_challenge': challenge,
      'state': state,
      'scope': 'user-read-recently-played',
    });
    final callback = Uri.parse(
      await FlutterWebAuth2.authenticate(
        url: authorizeUri.toString(),
        callbackUrlScheme: 'archiveme-spotify',
      ),
    );
    if (callback.host != 'callback' ||
        callback.path.isNotEmpty ||
        callback.queryParameters['state'] != state) {
      throw StateError('Spotify OAuth state validation failed.');
    }
    final code = callback.queryParameters['code'];
    if (code == null) throw StateError('Spotify authorization was cancelled.');
    return _exchange({
      'grant_type': 'authorization_code',
      'code': code,
      'redirect_uri': _redirectUri,
      'client_id': clientId,
      'code_verifier': verifier,
    });
  }

  @override
  Future<SpotifyCredential> refresh(String refreshToken) => _exchange({
    'grant_type': 'refresh_token',
    'refresh_token': refreshToken,
    'client_id': clientId,
  });

  Future<SpotifyCredential> _exchange(Map<String, String> body) async {
    final response = await _client.post(
      Uri.https('accounts.spotify.com', '/api/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: body,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Spotify authorization failed.');
    }
    final json = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    return SpotifyCredential(
      accessToken: '${json['access_token']}',
      refreshToken: '${json['refresh_token'] ?? body['refresh_token']}',
      expiresAt: DateTime.now().toUtc().add(
        Duration(seconds: (json['expires_in'] as num?)?.toInt() ?? 3600),
      ),
    );
  }

  String _randomText(int bytes) => base64UrlEncode(
    List<int>.generate(bytes, (_) => _random.nextInt(256)),
  ).replaceAll('=', '');
}

class SpotifyApi {
  SpotifyApi({
    required this.credentials,
    required this.oauth,
    http.Client? client,
    DateTime Function()? clock,
  }) : _client = client ?? http.Client(),
       _clock = clock ?? DateTime.now;

  final SpotifyCredentialStore credentials;
  final SpotifyOAuthGateway oauth;
  final http.Client _client;
  final DateTime Function() _clock;

  Future<List<SpotifyTrackSample>> recentlyPlayed() async {
    final credential = await _validCredential();
    final after = _clock()
        .toUtc()
        .subtract(const Duration(hours: 24))
        .millisecondsSinceEpoch;
    final response = await _client.get(
      Uri.https('api.spotify.com', '/v1/me/player/recently-played', {
        'limit': '50',
        'after': '$after',
      }),
      headers: {'Authorization': 'Bearer ${credential.accessToken}'},
    );
    if (response.statusCode != 200) {
      throw StateError('Spotify listening history is unavailable.');
    }
    final body = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    final rows = (body['items'] as List? ?? const []).whereType<Map>().toList();
    final ids = rows
        .map((row) => (row['track'] as Map?)?['id']?.toString())
        .whereType<String>()
        .toSet()
        .toList();
    final features = await _audioFeatures(ids, credential.accessToken);
    return rows
        .map((row) {
          final track = Map<String, dynamic>.from(row['track'] as Map);
          final artists = (track['artists'] as List? ?? const [])
              .whereType<Map>();
          final feature = features['${track['id']}'];
          return SpotifyTrackSample(
            trackId: '${track['id']}',
            playedAt:
                DateTime.tryParse('${row['played_at']}') ?? _clock().toUtc(),
            trackName: '${track['name']}',
            artistName: artists.isEmpty ? '' : '${artists.first['name']}',
            valence: (feature?['valence'] as num?)?.toDouble(),
            energy: (feature?['energy'] as num?)?.toDouble(),
          );
        })
        .toList(growable: false);
  }

  Future<Map<String, Map<String, dynamic>>> _audioFeatures(
    List<String> ids,
    String accessToken,
  ) async {
    if (ids.isEmpty) return const {};
    final response = await _client.get(
      Uri.https('api.spotify.com', '/v1/audio-features', {
        'ids': ids.take(100).join(','),
      }),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) return const {};
    final body = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    return {
      for (final item
          in (body['audio_features'] as List? ?? const []).whereType<Map>())
        if (item['id'] != null)
          '${item['id']}': Map<String, dynamic>.from(item),
    };
  }

  Future<SpotifyCredential> _validCredential() async {
    var credential = await credentials.read();
    if (credential == null) throw StateError('Spotify is not connected.');
    if (credential.expiresAt.isBefore(
      _clock().toUtc().add(const Duration(minutes: 5)),
    )) {
      credential = await oauth.refresh(credential.refreshToken);
      await credentials.write(credential);
    }
    return credential;
  }
}

abstract interface class SpotifyConnectorController {
  DateTime? get lastSyncAt;
  Future<bool> get connected;
  Future<void> connect();
  Future<void> disconnect();
  Future<void> syncNow();
}

class SpotifyConnector implements SpotifyConnectorController {
  SpotifyConnector({
    required this.credentials,
    required this.oauth,
    required this.api,
    required this.graphService,
    this.adapter = const SpotifyAdapter(),
    this.prefs,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  factory SpotifyConnector.platform({
    required BiometricVaultService vault,
    required ExternalGraphService graphService,
    MobilePrefsStore? prefs,
  }) {
    final credentials = BiometricSpotifyCredentialStore(vault: vault);
    final oauth = SpotifyPkceOAuthService(clientId: AppConfig.spotifyClientId);
    return SpotifyConnector(
      credentials: credentials,
      oauth: oauth,
      api: SpotifyApi(credentials: credentials, oauth: oauth),
      graphService: graphService,
      prefs: prefs,
    );
  }

  final SpotifyCredentialStore credentials;
  final SpotifyOAuthGateway oauth;
  final SpotifyApi api;
  final ExternalGraphService graphService;
  final SpotifyAdapter adapter;
  final MobilePrefsStore? prefs;
  final DateTime Function() _clock;
  static const _lastSyncPreferenceKey = 'external_spotify_last_sync_v1';

  @override
  DateTime? lastSyncAt;

  @override
  Future<bool> get connected async => await credentials.read() != null;

  Future<void> restore() async {
    lastSyncAt = DateTime.tryParse(
      await prefs?.readString(_lastSyncPreferenceKey) ?? '',
    );
  }

  @override
  Future<void> connect() async {
    await credentials.write(await oauth.authorize());
    await syncNow();
  }

  @override
  Future<void> disconnect() async {
    await credentials.clear();
    lastSyncAt = null;
    await prefs?.remove(_lastSyncPreferenceKey);
  }

  @override
  Future<void> syncNow() async {
    final tracks = await api.recentlyPlayed();
    await graphService.upsert(adapter.adapt(tracks));
    lastSyncAt = _clock().toUtc();
    await prefs?.writeString(
      _lastSyncPreferenceKey,
      lastSyncAt!.toIso8601String(),
    );
  }
}
