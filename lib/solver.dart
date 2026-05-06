class WordleSolverInput {
  WordleSolverInput({
    required this.greenPattern,
    required this.yellowByPosition,
    required this.grayLetters,
  });

  final List<String> greenPattern;
  final List<Set<String>> yellowByPosition;
  final Set<String> grayLetters;
}

class WordleSolverResult {
  WordleSolverResult({
    required this.positionRegex,
    required this.requiredYellowLetters,
    required this.candidates,
  });

  final String positionRegex;
  final Set<String> requiredYellowLetters;
  final List<String> candidates;
}

class WordleSolver {
  static const int wordLength = 5;

  WordleSolverResult solve({
    required WordleSolverInput input,
    required Iterable<String> words,
  }) {
    final regexSource = buildPositionRegex(input);
    final regex = RegExp(regexSource);
    final requiredYellowLetters = input.yellowByPosition
        .expand((letters) => letters)
        .toSet();

    final candidates = words
        .map((word) => word.trim().toLowerCase())
        .where((word) => RegExp(r'^[a-z]{5}$').hasMatch(word))
        .where(regex.hasMatch)
        .where((word) => requiredYellowLetters.every(word.contains))
        .toSet()
        .toList()
      ..sort();

    return WordleSolverResult(
      positionRegex: regexSource,
      requiredYellowLetters: requiredYellowLetters,
      candidates: candidates,
    );
  }

  String buildPositionRegex(WordleSolverInput input) {
    final buffer = StringBuffer('^');

    for (var position = 0; position < wordLength; position++) {
      final green = input.greenPattern[position];
      if (green.isNotEmpty && green != '*') {
        buffer.write(RegExp.escape(green));
        continue;
      }

      final excluded = <String>{
        ...input.grayLetters,
        ...input.yellowByPosition[position],
      }.where((letter) => RegExp(r'^[a-z]$').hasMatch(letter)).toList()
        ..sort();

      if (excluded.isEmpty) {
        buffer.write('[a-z]');
      } else {
        buffer.write('[^${excluded.map(RegExp.escape).join()}]');
      }
    }

    buffer.write(r'$');
    return buffer.toString();
  }
}

String normalizeSingleKnownCell(String value) {
  final normalized = value.toLowerCase().replaceAll(RegExp(r'[^a-z*]'), '');
  if (normalized.isEmpty) return '*';
  if (normalized.contains('*')) return '*';
  return normalized.substring(0, 1);
}

Set<String> normalizeLetterSet(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z]'), '')
      .split('')
      .where((letter) => letter.isNotEmpty)
      .toSet();
}
