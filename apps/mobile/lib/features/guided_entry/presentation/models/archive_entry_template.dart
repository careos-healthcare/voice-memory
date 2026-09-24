/// A pre-written page that opens in the editor with supporting moments.
class ArchiveEntryTemplate {
  const ArchiveEntryTemplate({
    required this.id,
    required this.title,
    required this.blurb,
    required this.pageBody,
    required this.patternStatement,
    required this.supportingMoments,
  });

  final String id;
  final String title;
  final String blurb;

  /// Body placed in the editor after the template is saved.
  final String pageBody;

  /// Statement scored against [supportingMoments] and [pageBody].
  final String patternStatement;

  final List<String> supportingMoments;

  String get pageEntryId => 'template-$id-page';

  String momentEntryId(int index) => 'template-$id-moment-$index';
}

/// Notion-style starter pages for a blank typed entry.
abstract final class ArchiveEntryTemplates {
  ArchiveEntryTemplates._();

  static const leaveBeforeDinner = ArchiveEntryTemplate(
    id: 'leave-before-dinner',
    title: 'Leave before dinner',
    blurb: 'A page about leaving the office earlier.',
    patternStatement: 'Leaving the office before dinner leaves me calmer',
    pageBody:
        'Leaving the office before dinner\n\n'
        'The walk home is quieter, and I feel calmer once I leave the office '
        'before dinner.',
    supportingMoments: [
      'Leaving the office before dinner left me calmer on the walk home tonight.',
      'I kept leaving the office before dinner and felt calmer than on the late nights.',
      'Leaving the office before dinner again made the evening calmer and quieter.',
    ],
  );

  static const walkAfterLunch = ArchiveEntryTemplate(
    id: 'walk-after-lunch',
    title: 'Walk after lunch',
    blurb: 'A page about stepping outside after lunch.',
    patternStatement: 'A short walk after lunch makes the afternoon clearer',
    pageBody:
        'A short walk after lunch\n\n'
        'I stepped outside after lunch and the afternoon felt clearer than '
        'the morning at my desk.',
    supportingMoments: [
      'Taking a short walk after lunch made the afternoon clearer and less crowded.',
      'A short walk after lunch left the afternoon clearer than staying at my desk.',
      'I took a short walk after lunch and the afternoon felt clearer right away.',
    ],
  );

  static const callOneFriend = ArchiveEntryTemplate(
    id: 'call-one-friend',
    title: 'Call one friend',
    blurb: 'A page about calling one friend.',
    patternStatement: 'Calling one friend each week makes the weekend lighter',
    pageBody:
        'Calling one friend each week\n\n'
        'I want to keep calling one friend each week so the weekend stays lighter.',
    supportingMoments: [
      'Calling one friend each week made the weekend feel lighter than staying quiet.',
      'I kept calling one friend each week and the weekend felt lighter afterward.',
      'Calling one friend each week again left the weekend lighter and less lonely.',
    ],
  );

  static const all = <ArchiveEntryTemplate>[
    leaveBeforeDinner,
    walkAfterLunch,
    callOneFriend,
  ];
}
