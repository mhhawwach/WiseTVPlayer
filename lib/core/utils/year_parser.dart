/// Utility to extract a production year from a movie/series title or
/// release-date string supplied by the Xtream Codes API.
///
/// IPTV panels frequently embed the year in the title, e.g.:
///   "The Batman (2022)"
///   "Oppenheimer 2023"
///   "Dune: Part Two (2024) [4K]"
///
/// [parseYearFromTitle] tries the most reliable patterns first and falls
/// back gracefully — returning null rather than guessing.
///
/// [parseYearFromReleaseDate] handles SeriesStream.releaseDate which is
/// typically "2023-01-15" or just "2023".
class YearParser {
  YearParser._();

  static const _minYear = 1900;
  static const _maxYear = 2030;

  /// Extracts the production year from a movie/series title.
  ///
  /// Priority:
  ///  1. Year in parentheses at or near the end: "Title (2024)"
  ///  2. 4-digit year at the very end: "Title 2024"
  ///  3. Any year-range `NNNN` in the title (last occurrence wins)
  static int? parseYearFromTitle(String title) {
    if (title.isEmpty) return null;

    // 1. Parenthesised year, possibly followed by resolution/tags
    //    e.g. "Title (2024)" or "Title (2024) [UHD]"
    final parenMatch = RegExp(r'\((\d{4})\)')
        .allMatches(title)
        .lastOrNull;
    if (parenMatch != null) {
      final y = int.tryParse(parenMatch.group(1)!);
      if (y != null && y >= _minYear && y <= _maxYear) return y;
    }

    // 2. Bare year at end of string, possibly with whitespace/punctuation
    final endMatch = RegExp(r'\b(\d{4})\s*$').firstMatch(title);
    if (endMatch != null) {
      final y = int.tryParse(endMatch.group(1)!);
      if (y != null && y >= _minYear && y <= _maxYear) return y;
    }

    // 3. Last 4-digit number in the plausible year range
    final allMatches = RegExp(r'\b((?:19|20)\d{2})\b').allMatches(title);
    if (allMatches.isNotEmpty) {
      final y = int.tryParse(allMatches.last.group(1)!);
      if (y != null && y >= _minYear && y <= _maxYear) return y;
    }

    return null;
  }

  /// Extracts the year from a release-date string like "2023-01-15" or "2023".
  static int? parseYearFromReleaseDate(String releaseDate) {
    if (releaseDate.trim().isEmpty) return null;
    final match = RegExp(r'^(\d{4})').firstMatch(releaseDate.trim());
    if (match == null) return null;
    final y = int.tryParse(match.group(1)!);
    if (y == null || y < _minYear || y > _maxYear) return null;
    return y;
  }
}

extension<T> on Iterable<T> {
  T? get lastOrNull {
    T? last;
    for (final e in this) { last = e; }
    return last;
  }
}
