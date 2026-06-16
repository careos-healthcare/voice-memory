import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/tomorrow_return/useful_result_takeaway_engine.dart';
import 'package:voicememory_mobile/features/tomorrow_return/useful_result_takeaway_model.dart';

void main() {
  UsefulResultTakeaway build(
    String hint, {
    String? reflectionText,
    String? notUsefulReason,
    bool inputQualityWeak = false,
  }) => buildUsefulResultTakeaway(
    resultHint: hint,
    checkInQuestion: 'Did this pattern show up again?',
    reflectionText: reflectionText,
    notUsefulReason: notUsefulReason,
    inputQualityWeak: inputQualityWeak,
  );

  group('result hint mapping', () {
    test('same / showed_up_again creates a repeat takeaway', () {
      for (final hint in ['same', 'showed_up_again']) {
        final t = build(hint);
        expect(t.type, UsefulResultTakeawayType.repeat);
        expect(t.headline, 'This was a repeat, not a one-off.');
        expect(t.whatItMeans, 'The same pattern showed up again today.');
        expect(
          t.whyUseful,
          'Repeats are useful because they show where to look next.',
        );
        expect(t.nextCheck, 'What happened right before it showed up?');
        expect(t.example, 'It started before I said yes.');
        expect(t.confidenceLabel, isNull);
      }
    });

    test('lighter creates a helped takeaway', () {
      final t = build('lighter');
      expect(t.type, UsefulResultTakeawayType.lighter);
      expect(t.headline, 'Something made this lighter.');
      expect(t.whatItMeans, 'Today this pattern took less from you.');
      expect(t.whyUseful, 'That is useful because it points to what helped.');
      expect(t.nextCheck, 'What helped make it lighter?');
      expect(t.example, 'It felt lighter after I paused.');
    });

    test('heavier creates an attention takeaway', () {
      final t = build('heavier');
      expect(t.type, UsefulResultTakeawayType.heavier);
      expect(t.headline, 'Something made this heavier.');
      expect(t.whatItMeans, 'Today this pattern took more from you.');
      expect(
        t.whyUseful,
        'That is useful because it shows what needs attention.',
      );
      expect(t.nextCheck, 'What made it heavier?');
      expect(t.example, 'It got heavier after I carried it alone.');
    });

    test('changed / not_today / none_fit creates a changed takeaway', () {
      for (final hint in ['changed', 'not_today', 'none_fit']) {
        final t = build(hint);
        expect(t.type, UsefulResultTakeawayType.changed);
        expect(t.headline, 'Today was different.');
        expect(t.whatItMeans, 'This was not just the same pattern repeating.');
        expect(
          t.whyUseful,
          'That is useful because change shows what can move.',
        );
        expect(t.nextCheck, 'What was different today?');
        expect(t.example, 'It changed when I waited before answering.');
      }
    });
  });

  group('reflection confidence', () {
    test('empty reflection shows Early read and a nudge', () {
      final t = build('lighter', reflectionText: '');
      expect(t.confidenceLabel, 'Early read');
      expect(
        t.whyUseful,
        contains('Add one more moment to make this clearer.'),
      );
    });

    test('very short reflection shows Early read', () {
      final t = build('same', reflectionText: 'yep');
      expect(t.confidenceLabel, 'Early read');
    });

    test('null reflection is not flagged as early', () {
      final t = build('same');
      expect(t.confidenceLabel, isNull);
      expect(t.whyUseful, isNot(contains('Add one more moment')));
    });

    test('long enough reflection is not flagged', () {
      final t = build(
        'same',
        reflectionText: 'It showed up right after lunch.',
      );
      expect(t.confidenceLabel, isNull);
    });
  });

  group('not-useful reasons', () {
    test('too_vague creates a concrete takeaway', () {
      final t = build('same', notUsefulReason: 'too_vague');
      expect(t.type, UsefulResultTakeawayType.concrete);
      expect(t.headline, 'Make this more concrete.');
      expect(t.whatItMeans, 'The next check should point to one moment.');
      expect(
        t.whyUseful,
        contains('One clear moment is easier to compare tomorrow.'),
      );
      expect(t.nextCheck, 'What exact moment did this show up?');
      expect(t.example, 'It showed up when I opened the message.');
    });

    test('already_knew_this adds repeat/change value copy', () {
      final t = build('lighter', notUsefulReason: 'already_knew_this');
      expect(t.type, UsefulResultTakeawayType.lighter);
      expect(
        t.whyUseful,
        contains('The value is whether it keeps happening or changes.'),
      );
    });

    test('not_accurate appends correction guidance', () {
      final t = build('heavier', notUsefulReason: 'not_accurate');
      expect(t.whyUseful, contains('Choose the closest answer'));
    });

    test('confusing appends a keep-it-simple nudge', () {
      final t = build('changed', notUsefulReason: 'confusing');
      expect(t.whyUseful, contains('lighter, heavier, or different.'));
    });

    test('too_vague still flags a thin reflection as Early read', () {
      final t = build('same', reflectionText: '', notUsefulReason: 'too_vague');
      expect(t.type, UsefulResultTakeawayType.concrete);
      expect(t.confidenceLabel, 'Early read');
    });
  });

  group('weak input', () {
    test('weak input shows Early read and a concrete next check', () {
      final t = build('same', inputQualityWeak: true);
      expect(t.confidenceLabel, 'Early read');
      expect(t.nextCheck, 'What exact moment did this show up?');
      expect(
        t.whyUseful,
        contains('Add one clearer moment to make this more useful.'),
      );
    });

    test('weak input keeps the result headline', () {
      final t = build('lighter', inputQualityWeak: true);
      expect(t.type, UsefulResultTakeawayType.lighter);
      expect(t.headline, 'Something made this lighter.');
      expect(t.confidenceLabel, 'Early read');
    });
  });
}
