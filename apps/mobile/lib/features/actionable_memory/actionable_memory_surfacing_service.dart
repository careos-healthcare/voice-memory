import 'package:archiveme_mobile/features/actionable_memory/actionable_memory_models.dart';
import 'package:archiveme_mobile/features/actionable_memory/actionable_memory_query.dart';
import 'package:archiveme_mobile/features/actionable_memory/gpt5_memory_synthesis_stub.dart';
import 'package:sqflite/sqflite.dart';

/// Delivers one organic notification. A platform scheduler plugs in here.
abstract interface class ActionableMemoryNotifier {
  Future<void> deliver(ActionableMemoryNotification notification);
}

/// Holds the latest notification until a push sender is attached.
class ActionableMemoryOutbox implements ActionableMemoryNotifier {
  ActionableMemoryNotification? latest;

  @override
  Future<void> deliver(ActionableMemoryNotification notification) async {
    latest = notification;
  }
}

/// Background pipeline: local history, then a GPT-5 synthesis stub.
///
/// Call [surface] from a worker that already opened the encrypted database.
/// The service does not schedule itself and does not open a network client.
class ActionableMemorySurfacingService {
  ActionableMemorySurfacingService({
    ActionableMemoryQuery? query,
    Gpt5MemorySynthesizer? synthesizer,
    ActionableMemoryNotifier? notifier,
  }) : _query = query ?? const ActionableMemoryQuery(),
       _synthesizer = synthesizer ?? const Gpt5MemorySynthesisStub(),
       _notifier = notifier ?? ActionableMemoryOutbox();

  final ActionableMemoryQuery _query;
  final Gpt5MemorySynthesizer _synthesizer;
  final ActionableMemoryNotifier _notifier;

  Future<ActionableMemorySurfaceResult?> surface({
    required DatabaseExecutor db,
    required ActionableMemoryContext context,
  }) async {
    final hits = await _query.find(db, context);
    if (hits.isEmpty) return null;
    final draft = await _synthesizer.synthesize(context: context, hits: hits);
    final notification = ActionableMemoryNotification(
      title: draft.title,
      body: draft.body,
      sourceEntryIds: draft.sourceEntryIds,
    );
    await _notifier.deliver(notification);
    return ActionableMemorySurfaceResult(
      notification: notification,
      request: draft.request,
      readyForRemoteSynthesis: draft.readyForRemoteSynthesis,
    );
  }
}

/// What a background run produced: a notification and the prepared GPT-5 request.
class ActionableMemorySurfaceResult {
  const ActionableMemorySurfaceResult({
    required this.notification,
    required this.request,
    required this.readyForRemoteSynthesis,
  });

  final ActionableMemoryNotification notification;
  final Gpt5MemorySynthesisRequest request;
  final bool readyForRemoteSynthesis;
}
