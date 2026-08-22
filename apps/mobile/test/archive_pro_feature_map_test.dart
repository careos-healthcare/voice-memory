import 'package:archiveme_mobile/billing/archive_pro_feature_map.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('core loop features are free', () {
    expect(ArchiveProFeatureMap.isFree(ArchiveFeature.recordMoment), isTrue);
    expect(ArchiveProFeatureMap.isFree(ArchiveFeature.firstPattern), isTrue);
    expect(ArchiveProFeatureMap.isFree(ArchiveFeature.tomorrowCheck), isTrue);
    expect(
      ArchiveProFeatureMap.isFree(ArchiveFeature.returnComparison),
      isTrue,
    );
    expect(ArchiveProFeatureMap.isFree(ArchiveFeature.usefulTakeaway), isTrue);
    expect(ArchiveProFeatureMap.isFree(ArchiveFeature.routineAnchor), isTrue);
    expect(
      ArchiveProFeatureMap.isFree(ArchiveFeature.lastSevenKeyMoments),
      isTrue,
    );
  });

  test('featureLabel and featureBenefit aliases work', () {
    expect(
      ArchiveProFeatureMap.featureLabel(ArchiveFeature.patternMap),
      ArchiveProFeatureMap.proFeatureLabel(ArchiveFeature.patternMap),
    );
    expect(
      ArchiveProFeatureMap.featureBenefit(ArchiveFeature.patternMap),
      ArchiveProFeatureMap.proFeatureBenefit(ArchiveFeature.patternMap),
    );
  });

  test('long-term archive memory features are Pro', () {
    for (final feature in ArchiveProFeatureMap.proFeatures) {
      expect(ArchiveProFeatureMap.isPro(feature), isTrue);
      expect(ArchiveProFeatureMap.proFeatureLabel(feature), isNotEmpty);
      expect(ArchiveProFeatureMap.proFeatureBenefit(feature), isNotEmpty);
    }
  });

  test('free key moments limit is 7', () {
    expect(ArchiveProFeatureMap.freeKeyMomentsLimit, 7);
  });
}