import 'dart:io';

import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Reads Apple Health State of Mind for the day a moment was saved.
abstract final class StateOfMindReader {
  StateOfMindReader._();

  static const channelName = 'archive_me/health_state_of_mind';
  static const MethodChannel channel = MethodChannel(channelName);

  @visibleForTesting
  static Future<String?> Function(DateTime day)? debugLookup;

  static Future<String?> forDay(DateTime day) async {
    final override = debugLookup;
    if (override != null) return override(day);
    if (kIsWeb || !Platform.isIOS) return null;
    try {
      final label = await channel.invokeMethod<String>('stateOfMind', {
        'date': day.toUtc().toIso8601String(),
      });
      final trimmed = label?.trim() ?? '';
      return trimmed.isEmpty ? null : trimmed;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  static Future<JournalEntry> attach(JournalEntry entry) async {
    final label = await forDay(entry.createdAt);
    if (label == null) return entry;
    final current = entry.reflection;
    return entry.copyWith(
      reflection: Reflection(
        mood: current.mood.isEmpty ? StateOfMindMood.word(label) : current.mood,
        emotionalIntensity: current.emotionalIntensity,
        recurringThemes: current.recurringThemes,
        exactLanguagePattern: current.exactLanguagePattern,
        concreteObservation: current.concreteObservation,
        repeatedSignal: current.repeatedSignal,
        tensionOrContradiction: current.tensionOrContradiction,
        avoidedOrVagueArea: current.avoidedOrVagueArea,
        nextSmallAction: current.nextSmallAction,
        patternObservations: current.patternObservations,
        healthStateOfMind: label,
      ),
    );
  }
}

/// Maps an Apple Health State of Mind label onto a short mood word and icon.
abstract final class StateOfMindMood {
  StateOfMindMood._();

  static const pleasant = {
    'amazed',
    'amused',
    'brave',
    'calm',
    'confident',
    'content',
    'excited',
    'grateful',
    'happy',
    'hopeful',
    'joyful',
    'passionate',
    'peaceful',
    'pleasant',
    'proud',
    'relieved',
  };

  static const unpleasant = {
    'angry',
    'anxious',
    'ashamed',
    'disappointed',
    'discouraged',
    'drained',
    'embarrassed',
    'frustrated',
    'guilty',
    'hopeless',
    'irritated',
    'jealous',
    'lonely',
    'overwhelmed',
    'sad',
    'scared',
    'stressed',
    'unpleasant',
    'worried',
  };

  static String word(String raw) {
    final key = raw.trim().toLowerCase();
    if (pleasant.contains(key)) return 'pleasant';
    if (unpleasant.contains(key)) return 'unpleasant';
    if (key.isEmpty) return '';
    return key;
  }

  static IconData icon(String raw) {
    final mapped = word(raw);
    if (mapped == 'pleasant') return Icons.sentiment_satisfied_alt_outlined;
    if (mapped == 'unpleasant') return Icons.sentiment_dissatisfied_outlined;
    return Icons.sentiment_neutral_outlined;
  }
}
