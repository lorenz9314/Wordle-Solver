import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'solver.dart';

void main() {
  runApp(const WordleSolverApp());
}

class WordleSolverApp extends StatelessWidget {
  const WordleSolverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Wordle Solver',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff3f7f5f)),
        useMaterial3: true,
      ),
      home: const SolverPage(),
    );
  }
}

class SolverPage extends StatefulWidget {
  const SolverPage({super.key});

  @override
  State<SolverPage> createState() => _SolverPageState();
}

class _SolverPageState extends State<SolverPage> {
  static const int columns = WordleSolver.wordLength;
  static const int rows = 6;

  final _knownControllers = List.generate(
    columns,
    (_) => TextEditingController(text: '*'),
  );

  final _yellowControllers = List.generate(
    rows - 1,
    (_) => List.generate(columns, (_) => TextEditingController()),
  );

  final _grayController = TextEditingController();
  final _solver = WordleSolver();

  List<String> _words = const [];
  WordleSolverResult? _result;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  Future<void> _loadWords() async {
    try {
      final raw = await rootBundle.loadString('assets/words.txt');
      final words = raw
          .split(RegExp(r'\r?\n'))
          .map((word) => word.trim().toLowerCase())
          .where((word) => RegExp(r'^[a-z]{5}$').hasMatch(word))
          .toSet()
          .toList()
        ..sort();

      setState(() {
        _words = words;
        _loadError = null;
      });
    } catch (error) {
      setState(() {
        _loadError = 'Could not load assets/words.txt: $error';
      });
    }
  }

  void _solve() {
    final greenPattern = _knownControllers
        .map((controller) => normalizeSingleKnownCell(controller.text))
        .toList();

    final yellowByPosition = List.generate(columns, (position) {
      final letters = <String>{};
      for (final row in _yellowControllers) {
        letters.addAll(normalizeLetterSet(row[position].text));
      }
      return letters;
    });

    final input = WordleSolverInput(
      greenPattern: greenPattern,
      yellowByPosition: yellowByPosition,
      grayLetters: normalizeLetterSet(_grayController.text),
    );

    setState(() {
      _result = _solver.solve(input: input, words: _words);
    });
  }

  void _clear() {
    for (final controller in _knownControllers) {
      controller.text = '*';
    }
    for (final row in _yellowControllers) {
      for (final controller in row) {
        controller.clear();
      }
    }
    _grayController.clear();
    setState(() {
      _result = null;
    });
  }

  @override
  void dispose() {
    for (final controller in _knownControllers) {
      controller.dispose();
    }
    for (final row in _yellowControllers) {
      for (final controller in row) {
        controller.dispose();
      }
    }
    _grayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wordle Solver'),
        actions: [
          IconButton(
            tooltip: 'Clear',
            onPressed: _clear,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Known letters',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            _KnownRow(controllers: _knownControllers),
            const SizedBox(height: 20),
            const Text(
              'Yellow letters excluded by position',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ..._yellowControllers.map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _YellowRow(controllers: row),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _grayController,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z]'))],
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Letters definitely not contained',
                hintText: 'e.g. spxui',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _words.isEmpty || _loadError != null ? null : _solve,
                icon: const Icon(Icons.search),
                label: const Text('Find candidates'),
              ),
            ),
            const SizedBox(height: 20),
            if (result == null && _loadError == null)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Enter constraints and press Find candidates.'),
                ),
              ),
            if (_loadError != null)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_loadError!),
                ),
              ),
            if (result != null) ...[
              _RegexCard(result: result, wordCount: _words.length),
              const SizedBox(height: 12),
              _CandidatesCard(candidates: result.candidates),
            ],
          ],
        ),
      ),
    );
  }
}

class _KnownRow extends StatelessWidget {
  const _KnownRow({required this.controllers});

  final List<TextEditingController> controllers;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final controller in controllers)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: TextField(
                controller: controller,
                textAlign: TextAlign.center,
                maxLength: 1,
                textCapitalization: TextCapitalization.none,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z*]'))],
                decoration: const InputDecoration(
                  counterText: '',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  final normalized = normalizeSingleKnownCell(value);
                  if (value != normalized) {
                    controller.value = TextEditingValue(
                      text: normalized,
                      selection: TextSelection.collapsed(offset: normalized.length),
                    );
                  }
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _YellowRow extends StatelessWidget {
  const _YellowRow({required this.controllers});

  final List<TextEditingController> controllers;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final controller in controllers)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: TextField(
                controller: controller,
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.none,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z]'))],
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RegexCard extends StatelessWidget {
  const _RegexCard({required this.result, required this.wordCount});

  final WordleSolverResult result;
  final int wordCount;

  @override
  Widget build(BuildContext context) {
    final yellow = result.requiredYellowLetters.toList()..sort();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Loaded words: $wordCount'),
            const SizedBox(height: 8),
            const Text('Position regex', style: TextStyle(fontWeight: FontWeight.w700)),
            SelectableText(result.positionRegex),
            const SizedBox(height: 8),
            const Text('Required yellow letters', style: TextStyle(fontWeight: FontWeight.w700)),
            SelectableText(yellow.isEmpty ? 'none' : yellow.join('')),
          ],
        ),
      ),
    );
  }
}

class _CandidatesCard extends StatelessWidget {
  const _CandidatesCard({required this.candidates});

  final List<String> candidates;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Candidates (${candidates.length})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (candidates.isEmpty)
              const Text('No matching words.')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final word in candidates.take(250))
                    Chip(label: Text(word)),
                  if (candidates.length > 250)
                    Chip(label: Text('+${candidates.length - 250} more')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
