import 'package:archiveme_mobile/core/hardware/resource_guard.dart';
import 'package:archiveme_mobile/services/ai/ai_service.dart';
import 'package:archiveme_mobile/services/ai/ai_service_bootstrap.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lazily created on-device Gemma AI service (null when bootstrap fails).
final aiServiceProvider = FutureProvider<AIService?>((ref) {
  return AiServiceBootstrap.tryCreate(resourceGuard: ResourceGuard.shared);
});
