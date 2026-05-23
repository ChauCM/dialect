@TestOn('vm')
library;

import 'dart:io';

import 'package:dialect/glossary/glossary_loader.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('Glossary.parse', () {
    test('returns empty when content is null/blank', () {
      expect(Glossary.parse('').terms, isEmpty);
      expect(Glossary.parse('# just a comment\n').terms, isEmpty);
    });

    test('parses a typical terms block', () {
      final g = Glossary.parse('''
terms:
  - term: "Book"
    meaning: "Verb. Make a reservation."
    translations:
      es: "Reservar"
      ja: "予約する"
''');
      expect(g.terms, hasLength(1));
      expect(g.terms.single.term, 'Book');
      expect(g.terms.single.translations['es'], 'Reservar');
      expect(g.terms.single.translations['ja'], '予約する');
      expect(g.terms.single.meaning, startsWith('Verb.'));
    });

    test('treats missing translations as empty map, not error', () {
      final g = Glossary.parse('''
terms:
  - term: "Trip"
    meaning: "A planned stay."
''');
      expect(g.terms.single.translations, isEmpty);
    });

    test('throws on malformed shape (term: list, terms: scalar, …)', () {
      expect(
        () => Glossary.parse('terms: not-a-list'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => Glossary.parse('terms:\n  - 42'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => Glossary.parse('terms:\n  - meaning: "…"'),
        throwsA(isA<FormatException>()), // missing `term:`
      );
    });
  });

  group('Glossary.loadFromProjectRoot', () {
    test('returns empty when no glossary.yaml exists', () {
      final tmp = Directory.systemTemp.createTempSync('dialect_gloss_');
      addTearDown(() {
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      });
      Directory(p.join(tmp.path, 'dialect')).createSync();
      expect(Glossary.loadFromProjectRoot(tmp.path).terms, isEmpty);
    });

    test('parses the file when present', () {
      final tmp = Directory.systemTemp.createTempSync('dialect_gloss_');
      addTearDown(() {
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      });
      final dialectDir = Directory(p.join(tmp.path, 'dialect'))..createSync();
      File(p.join(dialectDir.path, 'glossary.yaml')).writeAsStringSync('''
terms:
  - term: "Host"
    translations:
      de: "Gastgeber"
''');
      final g = Glossary.loadFromProjectRoot(tmp.path);
      expect(g.terms.single.term, 'Host');
      expect(g.terms.single.translations['de'], 'Gastgeber');
    });
  });
}
