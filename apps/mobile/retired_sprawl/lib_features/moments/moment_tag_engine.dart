import 'package:archiveme_mobile/features/moments/moment_tag_model.dart';

/// Maximum tags applied to any one moment — kept small so tags stay useful and
/// never feel noisy.
const int kMaxMomentTags = 5;

/// Conservative keyword sets per tag. A tag is only applied when one of its
/// plain keywords is present, so ArchiveMe never overclaims what a moment was
/// about. Result-driven tags (lighter/heavier/changed) come from the check-in
/// result, not the text.
const Map<MomentTag, List<String>> _keywords = {
  MomentTag.work: [
    'work',
    'job',
    'meeting',
    'deadline',
    'boss',
    'office',
    'shift',
    'colleague',
  ],
  MomentTag.family: [
    'family',
    'mum',
    'mom',
    'dad',
    'mother',
    'father',
    'parent',
    'kids',
    'child',
    'sister',
    'brother',
    'son',
    'daughter',
  ],
  MomentTag.partner: [
    'partner',
    'husband',
    'wife',
    'boyfriend',
    'girlfriend',
    'spouse',
  ],
  MomentTag.friend: ['friend', 'mate'],
  MomentTag.money: [
    'money',
    'rent',
    'bills',
    'salary',
    'debt',
    'afford',
    'cost',
    'broke',
  ],
  MomentTag.sleep: [
    'sleep',
    'slept',
    'insomnia',
    'awake',
    'nap',
    'rest',
    'bed',
  ],
  MomentTag.pressure: [
    'pressure',
    'guilt',
    'said yes',
    'had to',
    'should',
    'expected',
    'responsibility',
    'carry',
    'carried',
  ],
  MomentTag.worry: [
    'worry',
    'worried',
    'anxious',
    'nervous',
    'scared',
    'afraid',
  ],
  MomentTag.tired: [
    'tired',
    'exhausted',
    'drained',
    'no energy',
    'burnt out',
    'burned out',
    'flat',
  ],
  MomentTag.avoided: [
    'avoided',
    'delayed',
    'put off',
    'procrastinated',
    'ignored',
    'left it',
  ],
  MomentTag.helped: ['helped', 'paused', 'asked for help', 'reached out'],
};

/// Builds the tags for a moment. Deterministic order (the [MomentTag] enum
/// order), conservative keyword matching, capped at [kMaxMomentTags]. The
/// original text is never modified.
List<String> buildMomentTags(
  String text, {
  String? resultHint,
  int max = kMaxMomentTags,
}) {
  final lower = text.toLowerCase();
  final tags = <String>[];

  for (final tag in MomentTag.values) {
    final words = _keywords[tag];
    if (words != null && words.any(lower.contains)) {
      tags.add(tag.id);
    }
  }

  switch (resultHint) {
    case 'lighter':
      _addUnique(tags, MomentTag.lighter.id);
    case 'heavier':
      _addUnique(tags, MomentTag.heavier.id);
    case 'changed':
    case 'not_today':
    case 'none_fit':
      _addUnique(tags, MomentTag.changed.id);
  }

  if (tags.length > max) return tags.sublist(0, max);
  return tags;
}

void _addUnique(List<String> tags, String tag) {
  if (!tags.contains(tag)) tags.add(tag);
}