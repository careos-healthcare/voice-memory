import 'package:archiveme_mobile/features/guided_entry/presentation/models/time_of_day_prompt.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Resolves the blank-entry prompt from the device's current local hour.
class TimeOfDayPromptProvider extends Notifier<TimeOfDayPrompt> {
  TimeOfDayPromptProvider({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  @override
  TimeOfDayPrompt build() => TimeOfDayPrompt.resolve(_clock());
}

final timeOfDayPromptProvider =
    NotifierProvider<TimeOfDayPromptProvider, TimeOfDayPrompt>(
      TimeOfDayPromptProvider.new,
    );
