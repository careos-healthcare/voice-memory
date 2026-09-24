import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

/// People, places, and a mood found in one transcript.
class EntryEntityTags {
  const EntryEntityTags({
    required this.people,
    required this.locations,
    this.mood,
  });

  final List<String> people;
  final List<String> locations;
  final String? mood;

  bool get isEmpty => people.isEmpty && locations.isEmpty && mood == null;

  List<String> get labels => [
    for (final person in people) 'person:$person',
    for (final place in locations) 'place:$place',
    if (mood != null) 'mood:$mood',
  ];
}

const _moodWords = <String, String>{
  'calm': 'calm',
  'anxious': 'anxious',
  'overwhelmed': 'overwhelmed',
  'grateful': 'grateful',
  'hopeful': 'hopeful',
  'sad': 'sad',
  'angry': 'angry',
  'content': 'content',
  'tired': 'tired',
};

const _nameStops = {'The', 'This', 'That', 'Monday', 'Today', 'Yesterday'};

/// On-device extraction. Kept top-level so it can run in a background isolate.
EntryEntityTags extractEntryEntities(String transcript) {
  final text = transcript.trim();
  if (text.isEmpty) {
    return const EntryEntityTags(people: [], locations: []);
  }
  final people = <String>[];
  final locations = <String>[];
  for (final match in RegExp(
    r'\b(?:with|met|called)\s+([A-Z][a-z]+)\b',
  ).allMatches(text)) {
    final name = match.group(1)!;
    if (_nameStops.contains(name) || people.contains(name)) continue;
    people.add(name);
  }
  for (final match in RegExp(
    r'\b(?:in|at|from|near)\s+([A-Z][a-z]+)\b',
  ).allMatches(text)) {
    final place = match.group(1)!;
    if (_nameStops.contains(place) || locations.contains(place)) continue;
    locations.add(place);
  }
  String? mood;
  final words = text.toLowerCase().split(RegExp('[^a-z]+'));
  for (final word in words) {
    final found = _moodWords[word];
    if (found != null) {
      mood = found;
      break;
    }
  }
  return EntryEntityTags(people: people, locations: locations, mood: mood);
}

/// Persists people, place, and mood labels for one entry.
class EntryEntityTagStore {
  EntryEntityTagStore(this._db);

  final Database _db;
  static const table = 'entry_entity_tags';
  var _ready = false;

  Future<void> save(String entryId, EntryEntityTags tags) async {
    await _ensure();
    await _db.delete(table, where: 'entry_id = ?', whereArgs: [entryId]);
    final labels = tags.labels;
    for (var i = 0; i < labels.length; i++) {
      await _db.insert(table, {
        'entry_id': entryId,
        'tag': labels[i],
        'position': i,
      });
    }
  }

  Future<EntryEntityTags?> read(String entryId) async {
    await _ensure();
    final rows = await _db.query(
      table,
      columns: ['tag'],
      where: 'entry_id = ?',
      whereArgs: [entryId],
      orderBy: 'position',
    );
    if (rows.isEmpty) return null;
    final people = <String>[];
    final locations = <String>[];
    String? mood;
    for (final row in rows) {
      final tag = row['tag']! as String;
      if (tag.startsWith('person:')) {
        people.add(tag.substring('person:'.length));
      } else if (tag.startsWith('place:')) {
        locations.add(tag.substring('place:'.length));
      } else if (tag.startsWith('mood:')) {
        mood = tag.substring('mood:'.length);
      }
    }
    return EntryEntityTags(people: people, locations: locations, mood: mood);
  }

  Future<void> _ensure() async {
    if (_ready) return;
    await _db.execute('''
      CREATE TABLE IF NOT EXISTS $table (
        entry_id TEXT NOT NULL,
        tag TEXT NOT NULL,
        position INTEGER NOT NULL,
        PRIMARY KEY (entry_id, tag)
      )
    ''');
    _ready = true;
  }
}

/// Tags a transcript off the UI isolate, then stores the labels.
abstract final class EntryEntityTagger {
  static EntryEntityTagStore? store;

  static Future<EntryEntityTags> Function(String transcript) extract =
      _extractOffUi;

  static void bind(Database database) {
    store = EntryEntityTagStore(database);
  }

  static Future<void> onTranscriptReady(
    String transcript, {
    String? entryId,
  }) async {
    final id = entryId?.trim() ?? '';
    final text = transcript.trim();
    if (id.isEmpty || text.isEmpty) return;
    final tags = await extract(text);
    if (tags.isEmpty) return;
    final destination = store;
    if (destination == null) return;
    await destination.save(id, tags);
  }

  static Future<EntryEntityTags> _extractOffUi(String transcript) {
    if (kIsWeb || Platform.environment.containsKey('FLUTTER_TEST')) {
      return Future<EntryEntityTags>(() => extractEntryEntities(transcript));
    }
    return Isolate.run(() => extractEntryEntities(transcript));
  }
}
