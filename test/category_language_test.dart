import 'package:flutter_test/flutter_test.dart';
import 'package:wisetv_player/core/language/category_language.dart';
import 'package:wisetv_player/data/models/live_category.dart';

LiveCategory _c(String id, String name) =>
    LiveCategory(categoryId: id, categoryName: name, parentId: 0);

void main() {
  group('CategoryLanguage.detect — real WiseVOD names', () {
    // Live + VOD + Series category names taken verbatim from the playlist.
    const arabicNames = [
      'Arabic',
      'Arabic Series',
      'Lebanon TV',
      'Palestine TV',
      'The Holy Quran',
      'Ramadan 2026',
    ];
    for (final n in arabicNames) {
      test('"$n" → arabic', () => expect(CategoryLanguage.detect(n), 'arabic'));
    }

    test('"English Series" → english',
        () => expect(CategoryLanguage.detect('English Series'), 'english'));
    test('"Turkish Series" → turkish',
        () => expect(CategoryLanguage.detect('Turkish Series'), 'turkish'));
    test('"Korean Series" → korean',
        () => expect(CategoryLanguage.detect('Korean Series'), 'korean'));
    test('"Indian Series" → indian',
        () => expect(CategoryLanguage.detect('Indian Series'), 'indian'));
    test('"Iranian series" → persian',
        () => expect(CategoryLanguage.detect('Iranian series'), 'persian'));

    // Genre / untagged names must be uncategorized (null → always shown).
    const genres = [
      'Documentary', 'Drama', 'Movies', 'News', 'Sports', 'Music',
      'Religious', 'Lifestyle', 'Kids and anime', 'sh', 'NEW',
      'Action and Thriller', 'Comedy', 'Crime and Mystery', 'Family',
      'Fantasy', 'History', 'Horror', 'Romance', 'Science Fiction', 'War',
      'Western', 'Adventure',
    ];
    for (final n in genres) {
      test('"$n" → null (uncategorized)',
          () => expect(CategoryLanguage.detect(n), isNull));
    }
  });

  group('CategoryLanguage.detect — code prefixes & script', () {
    test('"EN | Movies" → english',
        () => expect(CategoryLanguage.detect('EN | Movies'), 'english'));
    test('"AR - News" → arabic',
        () => expect(CategoryLanguage.detect('AR - News'), 'arabic'));
    test('"FR Cinema" → french',
        () => expect(CategoryLanguage.detect('FR Cinema'), 'french'));
    test('"US Sports" → english',
        () => expect(CategoryLanguage.detect('US Sports'), 'english'));
    test('Arabic script → arabic',
        () => expect(CategoryLanguage.detect('قنوات عربية'), 'arabic'));
  });

  group('CategoryLanguage.detect — collision guards', () {
    // Common words that must NOT be mistaken for a language code.
    test('"Movies in HD" not indian ("in" dropped)',
        () => expect(CategoryLanguage.detect('Movies in HD'), isNull));
    test('"Filmes de Terror" not german ("de" dropped)',
        () => expect(CategoryLanguage.detect('Filmes de Terror'), isNull));
    test('"War" not arabic ("ar" needs a boundary)',
        () => expect(CategoryLanguage.detect('War'), isNull));
    test('"Music" not english ("us" needs a boundary)',
        () => expect(CategoryLanguage.detect('Music'), isNull));
    test('"Series" not spanish ("es" needs a boundary)',
        () => expect(CategoryLanguage.detect('Series'), isNull));
    test('"Romance" not romanian ("roman" excluded)',
        () => expect(CategoryLanguage.detect('Romance'), isNull));
  });

  group('CategoryLanguage.detect — big multilingual playlist (screenshot)', () {
    const cases = {
      'QUÉBEC SERIES': 'french', // accented É folded → quebec
      'QUÉBEC ANIMATION': 'french',
      'QUÉBEC DOCUMENTAIRE': 'french',
      'INDIA EN DUBBED SERIES': 'indian', // word beats the "EN" code
      'BULGARIYA SERIAL': 'bulgarian',
      'RUSSAIN SERIES': 'russian', // common misspelling
      'SVENSKA SERIE': 'swedish', // native name
      'DANSK SERIE': 'danish', // native name
      'HEBREW דיסני + סדרות': 'hebrew',
      'HEBREW המהדורות האחרונות': 'hebrew',
    };
    cases.forEach((name, lang) {
      test('"$name" → $lang',
          () => expect(CategoryLanguage.detect(name), lang));
    });

    // Diacritic folding for native names.
    test('"Español" → spanish',
        () => expect(CategoryLanguage.detect('Español'), 'spanish'));
    test('"Türkçe Dizi" → turkish',
        () => expect(CategoryLanguage.detect('Türkçe Dizi'), 'turkish'));
    test('"Português" → portuguese',
        () => expect(CategoryLanguage.detect('Português'), 'portuguese'));
    test('"USA Movies" → english (usa code, bounded)',
        () => expect(CategoryLanguage.detect('USA Movies'), 'english'));

    test('with only AR+EN selected, all of these are hidden', () {
      final cats = [
        for (final e in cases.keys.toList().asMap().entries)
          _c('${e.key}', e.value),
      ];
      final blocked =
          CategoryLanguage.blockedCategoryIds(cats, {'arabic', 'english'});
      // Every screenshot category is non-AR/EN → all blocked.
      expect(blocked.length, cats.length);
    });
  });

  group('languagesPresent / blocked / defaults', () {
    final series = [
      _c('1', 'Ramadan 2026'),
      _c('2', 'Arabic Series'),
      _c('3', 'English Series'),
      _c('4', 'Kids and anime'),
      _c('5', 'Korean Series'),
      _c('6', 'Indian Series'),
      _c('7', 'Iranian series'),
      _c('8', 'Turkish Series'),
      _c('9', 'The Holy Quran'),
      _c('10', 'NEW'),
    ];

    test('languagesPresent finds exactly the tagged languages', () {
      expect(CategoryLanguage.languagesPresent(series).toSet(),
          {'arabic', 'english', 'turkish', 'persian', 'indian', 'korean'});
    });

    test('default selection (AR+EN) hides the other tagged categories', () {
      final blocked =
          CategoryLanguage.blockedCategoryIds(series, {'arabic', 'english'});
      // Korean(5), Indian(6), Iranian(7), Turkish(8) hidden.
      expect(blocked, {'5', '6', '7', '8'});
      // Arabic / English / untagged (Kids, Quran, Ramadan, NEW) all shown.
      expect(blocked.contains('2'), isFalse); // Arabic Series
      expect(blocked.contains('3'), isFalse); // English Series
      expect(blocked.contains('4'), isFalse); // Kids and anime (untagged)
      expect(blocked.contains('9'), isFalse); // The Holy Quran (arabic)
      expect(blocked.contains('10'), isFalse); // NEW (untagged)
    });

    test('selecting Turkish reveals Turkish, still hides Korean/Indian', () {
      final blocked = CategoryLanguage.blockedCategoryIds(
          series, {'arabic', 'english', 'turkish'});
      expect(blocked.contains('8'), isFalse); // Turkish now visible
      expect(blocked, {'5', '6', '7'}); // Korean, Indian, Iranian still hidden
    });

    test('defaultSelectionFor prefers AR+EN when present', () {
      expect(
          CategoryLanguage.defaultSelectionFor(
              ['arabic', 'english', 'turkish']),
          {'arabic', 'english'});
    });

    test('defaultSelectionFor falls back to all when neither AR nor EN present',
        () {
      expect(CategoryLanguage.defaultSelectionFor(['turkish', 'korean']),
          {'turkish', 'korean'});
    });
  });
}
