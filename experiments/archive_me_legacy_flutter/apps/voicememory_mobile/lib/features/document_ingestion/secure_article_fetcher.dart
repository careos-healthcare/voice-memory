import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

class ArticleFetchException implements Exception {
  const ArticleFetchException(this.message);

  final String message;

  @override
  String toString() => 'ArticleFetchException: $message';
}

final class FetchedArticle {
  const FetchedArticle({
    required this.finalUri,
    required this.body,
    required this.contentType,
  });

  final Uri finalUri;
  final Uint8List body;
  final String contentType;
}

typedef HostResolver = Future<List<InternetAddress>> Function(String host);
typedef HttpClientFactory = HttpClient Function();

/// Fetches public HTTPS HTML without emitting request URLs or article data.
final class SecureArticleFetcher {
  SecureArticleFetcher({
    this.maxBodyBytes = 2 * 1024 * 1024,
    this.maxRedirects = 3,
    this.timeout = const Duration(seconds: 15),
    HostResolver? resolver,
    HttpClientFactory? clientFactory,
  }) : _resolver = resolver ?? InternetAddress.lookup,
       _clientFactory = clientFactory ?? HttpClient.new;

  final int maxBodyBytes;
  final int maxRedirects;
  final Duration timeout;
  final HostResolver _resolver;
  final HttpClientFactory _clientFactory;

  Future<FetchedArticle> fetch(Uri initialUri) async {
    var uri = initialUri;
    final client = _clientFactory()
      ..connectionTimeout = timeout
      ..idleTimeout = timeout
      ..autoUncompress = true;
    try {
      for (var redirects = 0; ; redirects++) {
        await _validatePublicHttps(uri);
        final request = await client.getUrl(uri).timeout(timeout);
        request.followRedirects = false;
        request.maxRedirects = 0;
        request.headers.set(HttpHeaders.acceptHeader, 'text/html');
        final response = await request.close().timeout(timeout);
        await _validatePublicHttps(uri);

        if (_isRedirect(response.statusCode)) {
          if (redirects >= maxRedirects) {
            throw const ArticleFetchException('Too many redirects.');
          }
          final location = response.headers.value(HttpHeaders.locationHeader);
          await _discardBounded(response);
          if (location == null) {
            throw const ArticleFetchException('Redirect has no location.');
          }
          uri = uri.resolve(location);
          await _validatePublicHttps(uri);
          continue;
        }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          await _discardBounded(response);
          throw ArticleFetchException(
            'Article request failed with status ${response.statusCode}.',
          );
        }
        final contentType = response.headers.contentType;
        if (contentType == null ||
            contentType.primaryType.toLowerCase() != 'text' ||
            contentType.subType.toLowerCase() != 'html') {
          await _discardBounded(response);
          throw const ArticleFetchException('Response is not HTML.');
        }
        final declaredLength = response.contentLength;
        if (declaredLength > maxBodyBytes) {
          throw const ArticleFetchException('Article body is too large.');
        }
        final builder = BytesBuilder(copy: false);
        var received = 0;
        await response
            .listen((chunk) {
              received += chunk.length;
              if (received > maxBodyBytes) {
                throw const ArticleFetchException('Article body is too large.');
              }
              builder.add(chunk);
            })
            .asFuture<void>()
            .timeout(timeout);
        await _validatePublicHttps(uri);
        return FetchedArticle(
          finalUri: uri,
          body: builder.takeBytes(),
          contentType: contentType.mimeType,
        );
      }
    } on TimeoutException {
      throw const ArticleFetchException('Article request timed out.');
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _validatePublicHttps(Uri uri) async {
    if (uri.scheme.toLowerCase() != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const ArticleFetchException(
        'Only public HTTPS article URLs are allowed.',
      );
    }
    final literal = InternetAddress.tryParse(uri.host);
    if (literal != null && _isForbidden(literal)) {
      throw const ArticleFetchException('Private network hosts are forbidden.');
    }
    final addresses = await _resolver(uri.host).timeout(timeout);
    if (addresses.isEmpty || addresses.any(_isForbidden)) {
      throw const ArticleFetchException('Private network hosts are forbidden.');
    }
  }

  bool _isRedirect(int status) =>
      status == 301 ||
      status == 302 ||
      status == 303 ||
      status == 307 ||
      status == 308;

  Future<void> _discardBounded(HttpClientResponse response) async {
    var received = 0;
    await response
        .listen((chunk) {
          received += chunk.length;
          if (received > maxBodyBytes) {
            throw const ArticleFetchException('Response body is too large.');
          }
        })
        .asFuture<void>()
        .timeout(timeout);
  }
}

bool _isForbidden(InternetAddress address) {
  final bytes = address.rawAddress;
  if (address.type == InternetAddressType.IPv4) {
    final a = bytes[0];
    final b = bytes[1];
    return a == 0 ||
        a == 10 ||
        a == 127 ||
        (a == 100 && b >= 64 && b <= 127) ||
        (a == 169 && b == 254) ||
        (a == 172 && b >= 16 && b <= 31) ||
        (a == 192 && b == 168) ||
        a >= 224;
  }
  if (address.type == InternetAddressType.IPv6) {
    final isMappedIpv4 =
        bytes.take(10).every((byte) => byte == 0) &&
        bytes[10] == 0xff &&
        bytes[11] == 0xff;
    if (isMappedIpv4) {
      return _isForbidden(
        InternetAddress.fromRawAddress(Uint8List.fromList(bytes.sublist(12))),
      );
    }
    final allZero = bytes.every((byte) => byte == 0);
    final loopback =
        bytes.take(15).every((byte) => byte == 0) && bytes.last == 1;
    final uniqueLocal = (bytes[0] & 0xfe) == 0xfc;
    final linkLocal = bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0x80;
    final siteLocal = bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0xc0;
    final multicast = bytes[0] == 0xff;
    return allZero ||
        loopback ||
        uniqueLocal ||
        linkLocal ||
        siteLocal ||
        multicast;
  }
  return true;
}
