import '../../api/api_exceptions.dart';
import '../../api/api_transport.dart';
import '../../services/capture_attest_service.dart';
import 'search_intent.dart';

abstract interface class SearchQueryTranslator {
  Future<SearchIntent> translate(String rawQuery);
}

class CloudSearchQueryTranslator implements SearchQueryTranslator {
  const CloudSearchQueryTranslator({
    required this.transport,
    required this.attest,
  });

  final ApiTransport transport;
  final CaptureAttestService attest;

  @override
  Future<SearchIntent> translate(String rawQuery) async {
    final token = await attest.ensureCaptureToken();
    final response = await transport.postJson(
      '/api/search-translator',
      headers: {
        ...transport.jsonHeaders,
        ApiTransport.captureTokenHeader: token,
        'x-vm-client': 'voicememory-mobile',
      },
      body: {'query': rawQuery},
    );
    final body = transport.decodeJson(response);
    if (body['ok'] != true || body['intent'] is! Map) {
      throw ApiException(
        body['error'] as String? ?? 'Search translation failed.',
        statusCode: response.statusCode,
        code: body['code'] as String?,
      );
    }
    return SearchIntent.fromJson(
      Map<String, dynamic>.from(body['intent'] as Map),
    );
  }
}

class LocalSearchQueryTranslator implements SearchQueryTranslator {
  const LocalSearchQueryTranslator({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  @override
  Future<SearchIntent> translate(String rawQuery) async {
    final query = rawQuery.trim();
    final normalized = query.toLowerCase();
    final nodeTypes = <OmniNodeType>{
      if (_containsAny(normalized, const ['who', 'person', 'people']))
        OmniNodeType.person,
      if (_containsAny(normalized, const [
        'felt',
        'feel',
        'emotion',
        'mood',
        'stress',
        'overwhelm',
        'anxious',
      ]))
        OmniNodeType.emotion,
      if (_containsAny(normalized, const ['goal', 'aim', 'want to']))
        OmniNodeType.goal,
      if (_containsAny(normalized, const ['habit', 'routine']))
        OmniNodeType.habit,
      if (_containsAny(normalized, const ['project', 'work']))
        OmniNodeType.project,
      if (_containsAny(normalized, const ['place', 'where']))
        OmniNodeType.place,
      if (_containsAny(normalized, const ['belief', 'believe']))
        OmniNodeType.belief,
    };
    return SearchIntent(
      semanticQuery: query,
      timeframe: _timeframe(normalized),
      nodeTypes: nodeTypes,
      requiredEntities: _quotedEntities(query),
    );
  }

  OmniSearchTimeframe? _timeframe(String query) {
    final now = _clock().toUtc();
    final midnight = DateTime.utc(now.year, now.month, now.day);
    if (query.contains('last summer')) {
      final year = now.year - (now.month >= 6 ? 1 : 2);
      return OmniSearchTimeframe(
        start: DateTime.utc(year, 6),
        end: DateTime.utc(year, 9),
      );
    }
    if (query.contains('two weeks ago') ||
        query.contains('last two weeks') ||
        query.contains('past two weeks')) {
      return OmniSearchTimeframe(
        start: midnight.subtract(const Duration(days: 14)),
        end: midnight,
      );
    }
    final match = RegExp(r'(?:last|past)\s+(\d+)\s+days?').firstMatch(query);
    if (match != null) {
      final days = int.tryParse(match.group(1) ?? '')?.clamp(1, 3650) ?? 90;
      return OmniSearchTimeframe(
        start: midnight.subtract(Duration(days: days)),
        end: midnight,
      );
    }
    if (query.contains('this month')) {
      return OmniSearchTimeframe(
        start: DateTime.utc(now.year, now.month),
        end: DateTime.utc(now.year, now.month + 1),
      );
    }
    if (query.contains('this year')) {
      return OmniSearchTimeframe(
        start: DateTime.utc(now.year),
        end: DateTime.utc(now.year + 1),
      );
    }
    return null;
  }
}

bool _containsAny(String value, List<String> needles) =>
    needles.any(value.contains);

List<String> _quotedEntities(String value) => RegExp(
  r'''["“]([^"”]+)["”]''',
).allMatches(value).map((match) => match.group(1)!.trim()).toSet().toList();
