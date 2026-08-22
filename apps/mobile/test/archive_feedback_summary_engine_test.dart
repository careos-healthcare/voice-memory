import 'package:archiveme_mobile/features/feedback/archive_feedback_model.dart';
import 'package:archiveme_mobile/features/feedback/archive_feedback_summary_engine.dart';
import 'package:flutter_test/flutter_test.dart';

ArchiveFeedback _f(ArchiveFeedbackType type) => ArchiveFeedback(
  id: '${type.id}-${DateTime.now().microsecondsSinceEpoch}',
  type: type,
  targetType: ArchiveFeedbackTargetType.checkInResult,
  createdAt: DateTime(2026, 6),
);

void main() {
  test('empty feedback yields the empty summary', () {
    final summary = buildArchiveFeedbackSummary(const []);
    expect(summary.total, 0);
    expect(summary.dominantIssue, isNull);
  });

  test('counts each feedback type', () {
    final summary = buildArchiveFeedbackSummary([
      _f(ArchiveFeedbackType.useful),
      _f(ArchiveFeedbackType.useful),
      _f(ArchiveFeedbackType.tooGeneric),
      _f(ArchiveFeedbackType.notMe),
      _f(ArchiveFeedbackType.alreadyKnew),
      _f(ArchiveFeedbackType.moreSpecific),
    ]);
    expect(summary.total, 6);
    expect(summary.usefulCount, 2);
    expect(summary.tooGenericCount, 1);
    expect(summary.notMeCount, 1);
    expect(summary.alreadyKnewCount, 1);
    expect(summary.moreSpecificCount, 1);
  });

  test('dominant issue requires at least two of one negative type', () {
    final one = buildArchiveFeedbackSummary([_f(ArchiveFeedbackType.notMe)]);
    expect(one.dominantIssue, isNull);

    final two = buildArchiveFeedbackSummary([
      _f(ArchiveFeedbackType.notMe),
      _f(ArchiveFeedbackType.notMe),
    ]);
    expect(two.dominantIssue, ArchiveFeedbackType.notMe);
  });

  test('useful taps never become the dominant issue', () {
    final summary = buildArchiveFeedbackSummary([
      _f(ArchiveFeedbackType.useful),
      _f(ArchiveFeedbackType.useful),
      _f(ArchiveFeedbackType.useful),
      _f(ArchiveFeedbackType.tooGeneric),
    ]);
    expect(summary.dominantIssue, isNull);
  });

  test('dominant issue is null when top negative types tie', () {
    final summary = buildArchiveFeedbackSummary([
      _f(ArchiveFeedbackType.tooGeneric),
      _f(ArchiveFeedbackType.tooGeneric),
      _f(ArchiveFeedbackType.notMe),
      _f(ArchiveFeedbackType.notMe),
    ]);
    expect(summary.dominantIssue, isNull);
  });

  test('dominant issue picks the highest negative count', () {
    final summary = buildArchiveFeedbackSummary([
      _f(ArchiveFeedbackType.tooGeneric),
      _f(ArchiveFeedbackType.tooGeneric),
      _f(ArchiveFeedbackType.moreSpecific),
      _f(ArchiveFeedbackType.moreSpecific),
      _f(ArchiveFeedbackType.moreSpecific),
    ]);
    expect(summary.dominantIssue, ArchiveFeedbackType.moreSpecific);
  });
}