/// First-five-minutes simplification copy — save one repeat, compare later.
library;

import '../release_candidate/v1_revenue_focus_policy.dart';
import '../three_moment_activation/three_moment_activation_copy.dart';
import '../../product/core_product_vision.dart';

abstract final class FirstFiveMinutesSimplificationCopy {
  FirstFiveMinutesSimplificationCopy._();

  static const firstUserJourney = V1RevenueFocusPolicy.firstUserJourney;

  static const headline = 'Start your life story';

  static const body = CoreProductVision.valueProposition;

  static const oneLinePositioning = 'ArchiveMe shows what keeps coming back.';

  static const whenToUseLine =
      'Use it when you notice: I have felt this before, done this before, avoided '
      'this before, or checked this before.';

  static const oneSentenceLine = 'One real sentence is enough.';

  static const savedMattersLine =
      'Saved moments give your archive something real to compare.';

  static const whatHappensNextLine =
      'After enough real moments, ArchiveMe can show the first useful proof.';

  static const firstProofPreviewLine = whatHappensNextLine;

  static const notNowLine =
      'No reports, dashboards, action items, or context work needed now.';

  static const notChatLine =
      'ChatGPT can suggest what to do. ArchiveMe shows what you already said before.';

  static const threeMomentLine = ThreeMomentActivationCopy.combinedBody;

  static const notStorageLine =
      'This is not where you store everything. It is where you save what repeats.';

  static const guardrail =
      'The first five minutes must focus only on saving one repeat and understanding '
      'that ArchiveMe compares it later.';

  static bool previewImpliesProofExists(String text) {
    final lower = text.toLowerCase();
    return lower.contains('proof exists') ||
        lower.contains('your proof is ready') ||
        lower.contains('first proof appeared') ||
        lower.contains('proof is here');
  }

  static Iterable<String> allVisibleStrings() sync* {
    yield firstUserJourney;
    yield threeMomentLine;
    yield headline;
    yield body;
    yield oneLinePositioning;
    yield whenToUseLine;
    yield oneSentenceLine;
    yield savedMattersLine;
    yield whatHappensNextLine;
    yield firstProofPreviewLine;
    yield notNowLine;
    yield notChatLine;
    yield notStorageLine;
    yield guardrail;
  }
}
