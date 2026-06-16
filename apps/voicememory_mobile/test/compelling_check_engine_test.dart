import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/feedback/archive_feedback_model.dart';
import 'package:voicememory_mobile/features/tomorrow_return/compelling_check_engine.dart';
import 'package:voicememory_mobile/features/tomorrow_return/compelling_check_model.dart';

void main() {
  test('tooGeneric feedback creates exact moment question', () {
    final check = buildCompellingCheck(
      baseQuestion: 'Did this pattern show up again?',
      feedback: ArchiveFeedbackType.tooGeneric,
    );
    expect(check.type, CompellingCheckType.exactMoment);
    expect(check.question, 'What exact moment did this show up?');
    expect(check.sharpnessLabel, CompellingCheckSharpness.mostSpecific);
  });

  test('moreSpecific feedback creates exact moment question', () {
    final check = buildCompellingCheck(
      baseQuestion: 'Did this pattern show up again?',
      feedback: ArchiveFeedbackType.moreSpecific,
    );
    expect(check.type, CompellingCheckType.exactMoment);
    expect(check.question, 'What exact moment did this show up?');
  });

  test('lighter result hint creates helped question', () {
    final check = buildCompellingCheck(
      baseQuestion: 'Did this pattern show up again?',
      resultHint: 'lighter',
    );
    expect(check.type, CompellingCheckType.helpedMoment);
    expect(check.question, 'What helped make it lighter?');
    expect(check.sharpnessLabel, CompellingCheckSharpness.practical);
  });

  test('heavier result hint creates heavier question', () {
    final check = buildCompellingCheck(
      baseQuestion: 'Did this pattern show up again?',
      resultHint: 'heavier',
    );
    expect(check.type, CompellingCheckType.heavierMoment);
    expect(check.question, 'What made it heavier?');
    expect(check.sharpnessLabel, CompellingCheckSharpness.direct);
  });

  test('changed result hint creates changed question', () {
    final check = buildCompellingCheck(
      baseQuestion: 'Did this pattern show up again?',
      resultHint: 'not_today',
    );
    expect(check.type, CompellingCheckType.changedMoment);
    expect(check.question, 'What was different today?');
  });

  test('responsibility pattern creates say-yes-before-check question', () {
    final check = buildCompellingCheck(
      baseQuestion: 'Did this pattern show up again?',
      patternTitle: 'Taking responsibility before saying yes',
    );
    expect(check.type, CompellingCheckType.beforeMoment);
    expect(check.question, 'Did you say yes before checking what you needed?');
  });

  test('vague base question falls back to before-it-shows-up question', () {
    final check = buildCompellingCheck(
      baseQuestion: 'Did this pattern show up again?',
    );
    expect(check.type, CompellingCheckType.repeatMoment);
    expect(check.question, 'What happens right before it shows up?');
  });

  test(
    'default sharpness is Most specific when feedback says moreSpecific',
    () {
      expect(
        defaultCompellingSharpnessLabel(
          feedback: ArchiveFeedbackType.moreSpecific,
        ),
        CompellingCheckSharpness.mostSpecific,
      );
    },
  );

  test('default sharpness is Direct when preferDirect is true', () {
    expect(
      defaultCompellingSharpnessLabel(preferDirect: true),
      CompellingCheckSharpness.direct,
    );
  });

  test('chooser options include all four sharpness labels', () {
    final options = buildCompellingCheckOptions(
      baseQuestion: 'Did this pattern show up again?',
      patternTitle: 'Worry when things get quiet',
    );
    expect(options.keys, containsAll(CompellingCheckSharpness.all));
  });
}
