import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

/// Host-side driver for [local_sync_query_performance_test.dart].
///
/// Run:
/// ```sh
/// flutter drive \
///   --driver=integration_test/driver/local_sync_query_performance_driver.dart \
///   --target=integration_test/local_sync_query_performance_test.dart
/// ```
Future<void> main() => integrationDriver(
      responseDataCallback: (Map<String, dynamic>? data) async {
        if (data == null || data.isEmpty) {
          stderr.writeln('No integration test reportData received.');
          return;
        }

        final outputDir = Directory('build/performance/integration');
        if (!outputDir.existsSync()) {
          outputDir.createSync(recursive: true);
        }

        await File('${outputDir.path}/integration_response_data.json')
            .writeAsString(const JsonEncoder.withIndent('  ').convert(data));

        final summary = <String, dynamic>{};
        for (final entry in data.entries) {
          if (entry.key.endsWith('_metrics') ||
              entry.key == 'local_sync_query_performance_summary') {
            summary[entry.key] = entry.value;
          }
        }

        await File('${outputDir.path}/local_sync_query_summary.json')
            .writeAsString(const JsonEncoder.withIndent('  ').convert(summary));

        for (final entry in data.entries) {
          if (!entry.key.endsWith('_timeline')) {
            continue;
          }
          final value = entry.value;
          if (value is! Map) {
            continue;
          }
          final timelinePath =
              '${outputDir.path}/${entry.key.replaceAll('_timeline', '')}.timeline.json';
          await File(timelinePath).writeAsString(
            const JsonEncoder.withIndent('  ').convert(value),
          );
        }

        stdout.writeln(
          'Wrote integration performance artifacts to ${outputDir.path}',
        );
      },
    );
