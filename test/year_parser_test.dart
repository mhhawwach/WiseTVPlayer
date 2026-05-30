import 'package:flutter_test/flutter_test.dart';
import 'package:wisetv_player/core/utils/year_parser.dart';

void main() {
  group('YearParser.parseYearFromTitle', () {
    test('parenthesised year', () {
      expect(YearParser.parseYearFromTitle('The Batman (2022)'), 2022);
    });

    test('parenthesised year with trailing tags', () {
      expect(
          YearParser.parseYearFromTitle('Dune: Part Two (2024) [4K]'), 2024);
    });

    test('bare year at end', () {
      expect(YearParser.parseYearFromTitle('Oppenheimer 2023'), 2023);
    });

    test('last plausible year wins when multiple present', () {
      // "1999" appears in the title but the production year tag is (2021)
      expect(
          YearParser.parseYearFromTitle('Party Like 1999 (2021)'), 2021);
    });

    test('returns null when no year', () {
      expect(YearParser.parseYearFromTitle('Inception'), isNull);
    });

    test('rejects implausible years', () {
      expect(YearParser.parseYearFromTitle('Episode 1234'), isNull);
    });

    test('empty string', () {
      expect(YearParser.parseYearFromTitle(''), isNull);
    });
  });

  group('YearParser.parseYearFromReleaseDate', () {
    test('full ISO date', () {
      expect(YearParser.parseYearFromReleaseDate('2023-01-15'), 2023);
    });

    test('year only', () {
      expect(YearParser.parseYearFromReleaseDate('2019'), 2019);
    });

    test('blank', () {
      expect(YearParser.parseYearFromReleaseDate('  '), isNull);
    });

    test('garbage', () {
      expect(YearParser.parseYearFromReleaseDate('coming soon'), isNull);
    });
  });
}
