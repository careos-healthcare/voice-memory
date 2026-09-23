import 'dart:convert';

import 'package:http/http.dart' as http;

/// Where a language-model call runs.
enum LlmExecutionTarget {
  /// On-device speech and the local model. Nothing leaves the device.
  localOffline,

  /// A user-supplied key for Claude, OpenAI, or a custom endpoint.
  cloudByok,
}

/// Work the router is allowed to place.
enum LlmWorkload {
  /// Entity and moment extraction. Always local.
  extraction,

  /// A long graph summary. Cloud only when the user enabled a key.
  longitudinalGraphSummary,

  /// A chat reply over retrieved moments. Cloud only when a key is set.
  chatReply,
}

/// Which hosted API a bring-your-own-key setting targets.
enum CloudByokProvider { claude, openAi, custom }

/// User choice for hosted summarization. The key is not stored here.
class CloudByokSettings {
  const CloudByokSettings({
    required this.enabled,
    required this.provider,
    required this.apiKey,
    this.endpoint,
  });

  const CloudByokSettings.disabled()
    : enabled = false,
      provider = CloudByokProvider.claude,
      apiKey = '',
      endpoint = null;

  final bool enabled;
  final CloudByokProvider provider;
  final String apiKey;
  final Uri? endpoint;

  bool get hasValidKey {
    if (!enabled || apiKey.trim().isEmpty) return false;
    if (provider == CloudByokProvider.custom) return endpoint != null;
    return true;
  }

  Uri? get requestUri {
    if (!hasValidKey) return null;
    return switch (provider) {
      CloudByokProvider.claude => Uri.https('api.anthropic.com', '/v1/messages'),
      CloudByokProvider.openAi => Uri.https(
        'api.openai.com',
        '/v1/chat/completions',
      ),
      CloudByokProvider.custom => endpoint,
    };
  }
}

/// Result of one routed call.
class LlmRouteResult {
  const LlmRouteResult({
    required this.target,
    required this.text,
    this.fellBack = false,
  });

  final LlmExecutionTarget target;
  final String text;
  final bool fellBack;
}

/// Local extraction by default, with an optional hosted summary path.
class LlmRouter {
  LlmRouter({
    Future<String> Function(String prompt)? local,
    this.cloud,
    this.settings = const CloudByokSettings.disabled(),
    this.httpClient,
  }) : local = local ?? _localExtract;

  final Future<String> Function(String prompt) local;
  final Future<String> Function(CloudByokSettings settings, String prompt)? cloud;
  final CloudByokSettings settings;
  final http.Client? httpClient;

  LlmExecutionTarget targetFor(LlmWorkload workload) {
    final cloudAllowed =
        workload == LlmWorkload.longitudinalGraphSummary ||
        workload == LlmWorkload.chatReply;
    if (cloudAllowed && settings.hasValidKey) {
      return LlmExecutionTarget.cloudByok;
    }
    return LlmExecutionTarget.localOffline;
  }

  Future<LlmRouteResult> run({
    required LlmWorkload workload,
    required String prompt,
  }) async {
    if (targetFor(workload) == LlmExecutionTarget.cloudByok) {
      try {
        final text = cloud == null
            ? await _cloudComplete(settings, prompt)
            : await cloud!(settings, prompt);
        return LlmRouteResult(target: LlmExecutionTarget.cloudByok, text: text);
      } on Object {
        return LlmRouteResult(
          target: LlmExecutionTarget.localOffline,
          text: await local(prompt),
          fellBack: true,
        );
      }
    }
    return LlmRouteResult(
      target: LlmExecutionTarget.localOffline,
      text: await local(prompt),
    );
  }

  Future<String> _cloudComplete(CloudByokSettings config, String prompt) async {
    final uri = config.requestUri;
    if (uri == null) {
      throw StateError('Cloud key is not ready');
    }
    final client = httpClient ?? http.Client();
    final closeClient = httpClient == null;
    try {
      final response = await client.post(
        uri,
        headers: _headers(config),
        body: jsonEncode(_body(config, prompt)),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('Cloud request failed');
      }
      return _readText(config.provider, response.body);
    } finally {
      if (closeClient) client.close();
    }
  }

  static Map<String, String> _headers(CloudByokSettings config) {
    final key = config.apiKey.trim();
    return switch (config.provider) {
      CloudByokProvider.claude => {
        'content-type': 'application/json',
        'x-api-key': key,
        'anthropic-version': '2023-06-01',
      },
      CloudByokProvider.openAi || CloudByokProvider.custom => {
        'content-type': 'application/json',
        'authorization': 'Bearer $key',
      },
    };
  }

  static Map<String, Object?> _body(CloudByokSettings config, String prompt) {
    return switch (config.provider) {
      CloudByokProvider.claude => {
        'model': 'claude-3-5-haiku-latest',
        'max_tokens': 800,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
      },
      CloudByokProvider.openAi || CloudByokProvider.custom => {
        'model': 'gpt-4o-mini',
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
      },
    };
  }

  static String _readText(CloudByokProvider provider, String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) return body;
    if (provider == CloudByokProvider.claude) {
      final content = decoded['content'];
      if (content is List && content.isNotEmpty) {
        final first = content.first;
        if (first is Map && first['text'] is String) {
          return first['text'] as String;
        }
      }
    }
    final choices = decoded['choices'];
    if (choices is List && choices.isNotEmpty) {
      final message = choices.first;
      if (message is Map) {
        final payload = message['message'];
        if (payload is Map && payload['content'] is String) {
          return payload['content'] as String;
        }
      }
    }
    return body;
  }

  static Future<String> _localExtract(String prompt) async {
    final words = prompt.trim();
    if (words.isEmpty) return '';
    if (words.length <= 280) return words;
    return words.substring(0, 280);
  }
}
