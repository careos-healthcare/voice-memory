import 'package:archiveme_mobile/features/insights/insight_synthesis_service.dart';
import 'package:archiveme_mobile/features/insights/widgets/insights_dashboard_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../storage/sqlite/support/configure_sqlite_test_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 6, 15, 12);

  List<JournalSnippet> entries() {
    return [
      JournalSnippet(
        id: 'garden-1',
        createdAt: DateTime(2026, 6, 12),
        transcript: 'grateful for the garden after a long walk',
      ),
      JournalSnippet(
        id: 'garden-2',
        createdAt: DateTime(2026, 6, 13),
        transcript: 'the garden felt calm and steady again',
      ),
      JournalSnippet(
        id: 'garden-3',
        createdAt: DateTime(2026, 6, 14),
        transcript: 'another morning in the garden',
      ),
      JournalSnippet(
        id: 'commute-1',
        createdAt: DateTime(2026, 6, 1),
        transcript: 'the commute was slow today',
      ),
      JournalSnippet(
        id: 'commute-2',
        createdAt: DateTime(2026, 6, 2),
        transcript: 'the commute ran late again',
      ),
    ];
  }

  test('weekly synthesis caches themes and a forgotten pattern', () async {
    configureSqliteTestFfi();
    final db = await openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    final service = InsightSynthesisService(cache: SqliteInsightCache(db));

    final first = await service.refresh(entries(), now: now);
    expect(first.weeklySynthesis, contains('garden'));
    expect(
      first.weeklyEntryIds,
      containsAll(['garden-1', 'garden-2', 'garden-3']),
    );
    expect(first.surpriseInsight, contains('commute'));
    expect(first.surpriseEntryIds, containsAll(['commute-1', 'commute-2']));

    final cached = await service.readCache();
    expect(cached!.weeklySynthesis, first.weeklySynthesis);
    expect(cached.surpriseInsight, first.surpriseInsight);
  });

  testWidgets('dashboard opens from cache and refreshes only on request', (
    tester,
  ) async {
    final now = DateTime.now();
    final recent = [
      JournalSnippet(
        id: 'garden-1',
        createdAt: now.subtract(const Duration(days: 1)),
        transcript: 'grateful for the garden after a long walk',
      ),
      JournalSnippet(
        id: 'garden-2',
        createdAt: now.subtract(const Duration(days: 2)),
        transcript: 'the garden felt calm and steady again',
      ),
      JournalSnippet(
        id: 'garden-3',
        createdAt: now.subtract(const Duration(days: 3)),
        transcript: 'another morning in the garden',
      ),
      JournalSnippet(
        id: 'commute-1',
        createdAt: now.subtract(const Duration(days: 20)),
        transcript: 'the commute was slow today',
      ),
      JournalSnippet(
        id: 'commute-2',
        createdAt: now.subtract(const Duration(days: 21)),
        transcript: 'the commute ran late again',
      ),
    ];
    final cache = MemoryInsightCache();
    await cache.write(
      WeeklyInsightSnapshot(
        generatedAt: now,
        weeklySynthesis: 'This week, "garden" showed up in 3 saved moments.',
        surpriseInsight: 'A pattern that went quiet this week: "commute".',
        weeklyEntryIds: const ['garden-1'],
        surpriseEntryIds: const ['commute-1'],
      ),
    );
    final service = _CountingSynthesis(cache);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          insightSynthesisServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: InsightsDashboardWidget(loadEntries: () async => recent),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Weekly Synthesis'), findsOneWidget);
    expect(find.text('Surprise Insights'), findsOneWidget);
    expect(find.textContaining('garden'), findsOneWidget);
    expect(service.refreshes, 0);

    await tester.tap(find.byKey(const Key('insights_refresh_button')));
    await tester.pumpAndSettle();

    expect(service.refreshes, 1);
    expect(find.textContaining('commute'), findsWidgets);
  });
}

class _CountingSynthesis extends InsightSynthesisService {
  _CountingSynthesis(InsightCache cache) : super(cache: cache);

  int refreshes = 0;

  @override
  Future<WeeklyInsightSnapshot> refresh(
    List<JournalSnippet> entries, {
    DateTime? now,
  }) async {
    refreshes += 1;
    return super.refresh(entries, now: now);
  }
}
