import 'package:archiveme_mobile/features/insight_share/insight_share_card_model.dart';
import 'package:archiveme_mobile/features/insight_share/insight_share_pii.dart';
import 'package:archiveme_mobile/features/referral/referral_invite_after_value.dart';
import 'package:archiveme_mobile/features/weekly_story/weekly_story_models.dart';
import 'package:intl/intl.dart';

/// Builds aggregate weekly pattern lines for share cards — never raw journal text.
abstract final class InsightShareCardBuilder {
  InsightShareCardBuilder._();

  static const headline = 'Your week in reflection';
  static const footer = 'ArchiveMe';
  static const referralSource = 'weekly_review';

  static InsightShareCardModel? build({required WeeklyArchiveStory? story}) {
    if (story == null || !story.hasSufficientData) return null;

    final patternLines = _buildPatternLines(story);
    if (patternLines.isEmpty) return null;

    final weekRangeLabel = _weekRangeLabel(story);
    final referralLink = ReferralInviteAfterValue.inviteLinkFor(referralSource);
    final id = 'weekly-insight-${story.weekEnd.toIso8601String().substring(0, 10)}';

    final model = InsightShareCardModel(
      id: id,
      weekRangeLabel: weekRangeLabel,
      headline: headline,
      patternLines: patternLines,
      footer: footer,
      referralLink: referralLink,
      referralSource: referralSource,
      plainTextShare: '',
    );

    return InsightShareCardModel(
      id: model.id,
      weekRangeLabel: model.weekRangeLabel,
      headline: model.headline,
      patternLines: model.patternLines,
      footer: model.footer,
      referralLink: model.referralLink,
      referralSource: model.referralSource,
      plainTextShare: _plainText(model),
    );
  }

  static String _weekRangeLabel(WeeklyArchiveStory story) {
    final formatter = DateFormat.yMMMd();
    final start = formatter.format(story.weekStart.toLocal());
    final end = formatter.format(story.weekEnd.toLocal());
    return InsightSharePii.strip('$start – $end');
  }

  static List<String> _buildPatternLines(WeeklyArchiveStory story) {
    final lines = <String>[];

    final count = story.reflectionCountThisWeek;
    lines.add('$count reflection${count == 1 ? '' : 's'} this week');

    if (story.topThemes.isNotEmpty) {
      final top = story.topThemes.first;
      final label = InsightSharePii.strip(top.label);
      if (label.isNotEmpty) {
        lines.add(
          top.count > 1
              ? 'Theme returning: $label (${top.count} mentions)'
              : 'Theme returning: $label',
        );
      }
    }

    if (story.growingThemes.isNotEmpty) {
      final growing = story.growingThemes.first;
      final label = InsightSharePii.strip(growing.label);
      if (label.isNotEmpty) {
        lines.add('$label returned more often this week');
      }
    }

    if (story.decliningThemes.isNotEmpty) {
      final declining = story.decliningThemes.first;
      final label = InsightSharePii.strip(declining.label);
      if (label.isNotEmpty) {
        lines.add('$label showed up less this week');
      }
    }

    return InsightSharePii.sanitizeLines(lines);
  }

  static String _plainText(InsightShareCardModel model) {
    return [
      model.headline,
      model.weekRangeLabel,
      ...model.patternLines,
      '',
      model.footer,
    ].join('\n');
  }
}