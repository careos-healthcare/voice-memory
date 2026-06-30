/// Copy for the lightweight TestFlight/beta mission card on Record.
abstract final class ArchiveBetaMissionCopy {
  ArchiveBetaMissionCopy._();

  static const title = 'Beta mission';

  static const intro = 'To test ArchiveMe properly:';

  static const step1 = 'Record one real moment.';
  static const step2 = 'Come back and record something similar.';
  static const step3 =
      'Add a third moment so ArchiveMe can check what repeats.';

  static const feedbackLine =
      'Then tell us if the evidence felt specific or generic.';

  static const steps = [step1, step2, step3];

  static const startCta = 'Start with one moment';
  static const hideCta = 'Hide this';
}
