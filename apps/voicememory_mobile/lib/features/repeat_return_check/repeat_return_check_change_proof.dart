import 'repeat_return_check_copy.dart';
import 'repeat_return_check_models.dart';

/// Visible change-over-time proof from user repeat return checks.
class RepeatReturnCheckChangeProof {
  const RepeatReturnCheckChangeProof({
    required this.title,
    required this.body,
    required this.latestChoice,
    this.supportLine,
  });

  final String title;
  final String body;
  final String? supportLine;
  final RepeatReturnCheckChoice latestChoice;

  static const fromCopy = RepeatReturnCheckChangeProof(
    title: RepeatReturnCheckCopy.changeProofTitle,
    body: '',
    latestChoice: RepeatReturnCheckChoice.same,
  );
}
