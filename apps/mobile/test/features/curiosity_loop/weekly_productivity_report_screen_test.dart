import 'dart:io';

import 'package:archiveme_mobile/features/curiosity_loop/data/repositories/curiosity_reaction_repository.dart';
import 'package:archiveme_mobile/features/curiosity_loop/domain/services/cognitive_trajectory_evaluator.dart';
import 'package:archiveme_mobile/features/curiosity_loop/presentation/models/telemetry_data_point.dart';
import 'package:archiveme_mobile/features/curiosity_loop/presentation/weekly_productivity_report_screen.dart';
import 'package:archiveme_mobile/features/curiosity_loop/services/curiosity_data_exporter.dart';
import 'package:archiveme_mobile/features/curiosity_loop/services/productivity_report_engine.dart';
import 'package:archiveme_mobile/features/curiosity_loop/weekly_productivity_report_copy.dart';
import 'package:archiveme_mobile/features/curiosity_loop/yesterdays_snapshot_reaction.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _SpyCuriosityDataExporter extends CuriosityDataExporter {
  _SpyCuriosityDataExporter({required super.journalService})
    : super(reactionRepository: InMemoryCuriosityReactionRepository());

  int markdownCalls = 0;
  DateTime? lastMarkdownStart;
  DateTime? lastMarkdownEnd;

  @override
  Future<String> exportAsMarkdown({
    required DateTime start,
    required DateTime end,
  }) async {
    markdownCalls++;
    lastMarkdownStart = start;
    lastMarkdownEnd = end;
    return '# ArchiveMe — Curiosity Loop Export\n\n**Anchor:** said yes again';
  }

  @override
  Future<Map<String, dynamic>> exportAsJson({
    required DateTime start,
    required DateTime end,
  }) async {
    return {
      'schemaVersion': CuriosityDataExporter.schemaVersion,
      'window': {
        'start': start.toUtc().toIso8601String(),
        'end': end.toUtc().toIso8601String(),
      },
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await AppServices.resetForTest(
      journalPath:
          '${Directory.systemTemp.createTempSync('weekly_report_j_').path}/journal.json',
      prefsPath:
          '${Directory.systemTemp.createTempSync('weekly_report_p_').path}/prefs.json',
      skipRevenueCat: true,
    );
  });

  group('WeeklyProductivityReportScreen', () {
    testWidgets('renders warm empty state when there are no check-ins', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const WeeklyProductivityReportScreen.test(
            report: WeeklyProductivityReport(
              totalReactions: 0,
              reactionBreakdown: {},
              stuckAnchors: [],
              momentumAnchors: [],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('weekly_productivity_report_empty')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('weekly_productivity_report_empty_title')),
        findsOneWidget,
      );
      expect(
        find.text(WeeklyProductivityReportCopy.emptyTitle),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('weekly_productivity_report_empty_body')),
        findsOneWidget,
      );
      expect(find.text(WeeklyProductivityReportCopy.emptyBody), findsOneWidget);
      expect(
        find.byKey(const Key('weekly_productivity_report_loaded')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('weekly_productivity_report_hero')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('weekly_productivity_report_export_section')),
        findsNothing,
      );
    });

    testWidgets('renders populated weekly report layout', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const WeeklyProductivityReportScreen.test(
            report: WeeklyProductivityReport(
              totalReactions: 6,
              reactionBreakdown: {
                'progressed': 0.5,
                'stuck': 1 / 3,
                'pivot': 1 / 6,
              },
              stuckAnchors: ['said yes again'],
              momentumAnchors: ['finished the draft', 'shipped the fix'],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('weekly_productivity_report_loaded')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('weekly_productivity_report_hero')),
        findsOneWidget,
      );
      expect(
        find.text(WeeklyProductivityReportCopy.heroSubtitle(6)),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('weekly_productivity_report_breakdown')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          Key(
            'weekly_productivity_report_reaction_${YesterdaysSnapshotReaction.progressed.name}',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          Key(
            'weekly_productivity_report_reaction_${YesterdaysSnapshotReaction.stuck.name}',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          Key(
            'weekly_productivity_report_reaction_${YesterdaysSnapshotReaction.pivot.name}',
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('33%'), findsOneWidget);
      expect(find.text('17%'), findsOneWidget);

      expect(
        find.byKey(const Key('weekly_productivity_report_momentum')),
        findsOneWidget,
      );
      expect(
        find.text(WeeklyProductivityReportCopy.momentumTitle),
        findsOneWidget,
      );
      expect(find.text('finished the draft'), findsOneWidget);
      expect(find.text('shipped the fix'), findsOneWidget);

      expect(
        find.byKey(const Key('weekly_productivity_report_obstacles')),
        findsOneWidget,
      );
      expect(
        find.text(WeeklyProductivityReportCopy.obstaclesTitle),
        findsOneWidget,
      );
      expect(find.text('said yes again'), findsOneWidget);

      expect(
        find.byKey(const Key('weekly_productivity_report_empty')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('weekly_productivity_report_export_section')),
        findsOneWidget,
      );
      expect(
        find.text(WeeklyProductivityReportCopy.exportMarkdownLabel),
        findsOneWidget,
      );
      expect(
        find.text(WeeklyProductivityReportCopy.exportJsonLabel),
        findsOneWidget,
      );
    });

    testWidgets('renders clinical trajectory trend when history points exist', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: WeeklyProductivityReportScreen.test(
            report: const WeeklyProductivityReport(
              totalReactions: 2,
              reactionBreakdown: {
                'progressed': 1.0,
                'stuck': 0.0,
                'pivot': 0.0,
              },
              stuckAnchors: [],
              momentumAnchors: ['finished the draft'],
            ),
            initialTrajectoryPoints: [
              TelemetryDataPoint(
                date: DateTime.utc(2026, 6, 10),
                direction: CognitiveDirection.recovering,
                lexicalDelta: 0.20,
                driftDelta: -0.25,
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('weekly_productivity_report_trajectory_trend')),
        findsOneWidget,
      );
      expect(find.text('Clinical Telemetry & Down-Regulation'), findsOneWidget);
      expect(
        find.byKey(const Key('clinical_telemetry_rolling_health_score')),
        findsOneWidget,
      );
      expect(find.text('Rolling Stability Index'), findsOneWidget);
      expect(find.text('40 / 100'), findsOneWidget);
      expect(find.text('Needs attention'), findsOneWidget);
    });

    testWidgets('markdown export button calls exporter and shows toast', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final exporter = _SpyCuriosityDataExporter(
        journalService: AppServices.instance.journal,
      );
      var copiedMarkdown = '';

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: WeeklyProductivityReportScreen.test(
            report: const WeeklyProductivityReport(
              totalReactions: 2,
              reactionBreakdown: {
                'progressed': 0.5,
                'stuck': 0.5,
                'pivot': 0.0,
              },
              stuckAnchors: ['said yes again'],
              momentumAnchors: ['finished the draft'],
            ),
            exporter: exporter,
            markdownCopyHandler: (markdown) async {
              copiedMarkdown = markdown;
            },
          ),
        ),
      );
      await tester.pump();

      await tester.ensureVisible(
        find.byKey(const Key('weekly_productivity_report_export_markdown')),
      );
      await tester.tap(
        find.byKey(const Key('weekly_productivity_report_export_markdown')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(exporter.markdownCalls, 1);
      expect(exporter.lastMarkdownStart, isNotNull);
      expect(exporter.lastMarkdownEnd, isNotNull);
      expect(copiedMarkdown, contains('ArchiveMe — Curiosity Loop Export'));
      expect(copiedMarkdown, contains('said yes again'));
      expect(
        find.text(WeeklyProductivityReportCopy.markdownCopiedToast),
        findsOneWidget,
      );
    });
  });
}