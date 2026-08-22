/// Optional context tags for where/when a pressure moment showed up.
///
/// Always optional — a pressure check-in must save without any context.
enum PressureContext {
  work(id: 'work', label: 'Work'),
  personal(id: 'personal', label: 'Personal'),
  evening(id: 'evening', label: 'Evening'),
  beforeSleep(id: 'before_sleep', label: 'Before sleep'),
  afterPraiseCriticism(
    id: 'after_praise_criticism',
    label: 'After praise/criticism',
  ),
  deadline(id: 'deadline', label: 'Deadline'),
  family(id: 'family', label: 'Family'),
  money(id: 'money', label: 'Money'),
  health(id: 'health', label: 'Health'),
  stopping(id: 'stopping', label: 'Stopping'),
  people(id: 'people', label: 'People'),
  energy(id: 'energy', label: 'Energy');

  const PressureContext({required this.id, required this.label});

  final String id;
  final String label;

  static PressureContext? fromId(String? id) {
    if (id == null) return null;
    for (final context in PressureContext.values) {
      if (context.id == id) return context;
    }
    return null;
  }
}