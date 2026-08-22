import 'package:archiveme_mobile/database/app_database.dart';
import 'package:archiveme_mobile/features/weekly_synthesis/domain/recurrent_topic_cluster.dart';
import 'package:archiveme_mobile/features/weekly_synthesis/weekly_synthesis_config.dart';

/// Finds recurrent reflection-graph theme nodes via SQLite + FTS5 index.
final class RecurrentTopicNodeQuery {
  RecurrentTopicNodeQuery(AppDatabase db) : _dao = db.reflectionGraphDao;

  final ReflectionGraphDao _dao;

  Future<List<RecurrentTopicCluster>> fetchRecurrentTopics({
    required DateTime since,
    int minMentions = WeeklySynthesisConfig.minTopicMentions,
    int limit = WeeklySynthesisConfig.maxTopicClusters,
  }) =>
      _dao.fetchRecurrentTopics(
        since: since,
        minMentions: minMentions,
        limit: limit,
      );
}
