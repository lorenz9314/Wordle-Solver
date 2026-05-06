# Unofficial Solver for Wordle Puzzles

An unofficial solver for wordle puzzles. This app is a static single page implementation, built using flutter.

## How it works

The app loads `assets/words.txt` into the browser via Flutter assets. Replace this file with a larger five-letter English word list, one word per line.

Filtering uses two checks:

1. A position regex constructed from green letters, gray letters, and yellow position exclusions.
2. A containment check that requires all yellow letters to occur somewhere in the candidate word.

Example:

```text
Known row: r * m * n
Yellow exclusions: column 2 contains e, column 4 contains a
Gray letters: spxui
Regex: ^r[^eipsux]m[^aipsux]n$
Required yellow letters: ae
```

## Run locally

```bash
flutter pub get
flutter run -d chrome
```

## Build for static hosting

```bash
flutter build web --release
```

The generated `build/web` directory can be served as static files.
