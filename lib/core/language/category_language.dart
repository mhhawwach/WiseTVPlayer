/// Maps an Xtream **category name** to the (human) language it targets, so the
/// per-profile language filter can show only the languages a user cares about.
///
/// Design (decided with the user, grounded in real playlists):
///  • "Smart" matching, in this precedence:
///      1. Non-Latin **script** (Arabic / Hebrew / Greek) anywhere in the name.
///      2. **Descriptive words** — full language names, native self-names
///         ("svenska", "dansk", "bulgariya"), region/country names ("Québec",
///         "Lebanon"), content markers ("Quran"). Matched as a **substring** of
///         the diacritic-normalised, lower-cased name, so "Québec"→quebec and
///         "Iranian"→iranian both hit. Words are curated to be ≥4 chars and
///         collision-safe against English genre names.
///      3. **2-letter codes** ("EN", "AR", "FR"…) — matched only at word
///         boundaries, and only if no descriptive word matched. This is why
///         "INDIA EN DUBBED" resolves to Indian (word) not English (code).
///  • A name with **no** marker (genres like Drama/Comedy/News/Sports, or junk
///    like "NEW") returns `null` → "uncategorized" → ALWAYS shown.
///  • The popup is **auto-detect**: it offers exactly the languages found in the
///    playlist (see [languagesPresent]); Arabic + English are the defaults.
///
/// Pure logic only — no Flutter / storage deps — so it's trivially unit-testable.
library;

import '../../data/models/live_category.dart';

/// One detectable language: a stable [key], a display [label], a short [code]
/// chip (e.g. "AR"), and the matcher keyword groups.
class LanguageDef {
  final String key;
  final String label;
  final String code;

  /// Descriptive markers matched as a **substring** of the normalised name:
  /// full language names, native self-names, region/country names, content
  /// keywords. Keep each ≥4 chars and distinct from English genre words.
  final List<String> words;

  /// Short codes matched only at **word boundaries** (surrounded by non-letters)
  /// so they don't fire inside unrelated words ("war", "music", "series").
  /// Lower priority than [words].
  final List<String> codes;

  const LanguageDef({
    required this.key,
    required this.label,
    required this.code,
    this.words = const [],
    this.codes = const [],
  });
}

class CategoryLanguage {
  CategoryLanguage._();

  /// The detectable-language registry, in detection priority order. Arabic and
  /// English lead (they're the defaults); a name almost always carries a single
  /// clear marker, but order resolves the rare overlap (first match wins).
  static const List<LanguageDef> definitions = [
    LanguageDef(
      key: 'arabic',
      label: 'Arabic',
      code: 'AR',
      words: [
        'arabic', 'arab', 'arabe', 'arabia', 'arabiya',
        // Arabic-speaking countries / regions used as the "language".
        'lebanon', 'lebanese', 'palestine', 'palestinian', 'egypt', 'egyptian',
        'syria', 'syrian', 'iraq', 'iraqi', 'jordan', 'jordanian', 'saudi',
        'emirates', 'kuwait', 'qatar', 'bahrain', 'yemen', 'yemeni',
        'morocco', 'moroccan', 'algeria', 'algerian', 'tunisia', 'tunisian',
        'libya', 'libyan', 'sudan', 'sudanese', 'khaleeji', 'maghreb',
        'levant', 'rotana', 'shahid',
        // Arabic content markers.
        'quran', 'koran', 'islamic', 'ramadan',
      ],
      // 'oman' is a code, not a word — as a substring it embeds in "rOMANce",
      // "wOMAN", "rOMAN". Bounded matching catches a standalone "Oman" only.
      codes: ['ar', 'ksa', 'uae', 'mbc', 'osn', 'oman'],
    ),
    LanguageDef(
      key: 'english',
      label: 'English',
      code: 'EN',
      words: ['english', 'britain', 'british', 'america', 'american',
        'ireland', 'irish'],
      codes: ['en', 'eng', 'uk', 'us', 'usa'],
    ),
    LanguageDef(
      key: 'french',
      label: 'French',
      code: 'FR',
      words: ['french', 'france', 'francais', 'francaise', 'francophone',
        'quebec', 'quebecois'],
      codes: ['fr'],
    ),
    LanguageDef(
      key: 'german',
      label: 'German',
      code: 'DE',
      words: ['german', 'germany', 'deutsch', 'deutsche', 'deutschland',
        'austria', 'austrian'],
      // 'de' excluded — collides with Romance "de" ("Filmes de Terror").
      codes: [],
    ),
    LanguageDef(
      key: 'spanish',
      label: 'Spanish',
      code: 'ES',
      words: ['spanish', 'spain', 'espanol', 'espana', 'castellano', 'latino',
        'mexico', 'mexican'],
      codes: ['es'],
    ),
    LanguageDef(
      key: 'italian',
      label: 'Italian',
      code: 'IT',
      words: ['italian', 'italy', 'italia', 'italiano'],
      codes: ['it'],
    ),
    LanguageDef(
      key: 'portuguese',
      label: 'Portuguese',
      code: 'PT',
      words: ['portuguese', 'portugal', 'portugues', 'brasil', 'brazil',
        'brazilian'],
      codes: ['pt', 'br'],
    ),
    LanguageDef(
      key: 'turkish',
      label: 'Turkish',
      code: 'TR',
      words: ['turkish', 'turkey', 'turk', 'turkce', 'turkiye'],
      codes: ['tr'],
    ),
    LanguageDef(
      key: 'russian',
      label: 'Russian',
      code: 'RU',
      words: ['russian', 'russia', 'russain', 'russe', 'rossiya'],
      codes: ['ru'],
    ),
    LanguageDef(
      key: 'persian',
      label: 'Persian',
      code: 'FA',
      words: ['persian', 'iranian', 'farsi', 'parsi'],
      codes: ['fa', 'ir', 'iran'],
    ),
    LanguageDef(
      key: 'kurdish',
      label: 'Kurdish',
      code: 'KU',
      words: ['kurdish', 'kurd', 'kurdistan', 'kurmanji', 'sorani'],
      codes: [],
    ),
    LanguageDef(
      key: 'hebrew',
      label: 'Hebrew',
      code: 'HE',
      words: ['hebrew', 'ivrit', 'israel', 'israeli'],
      codes: [],
    ),
    LanguageDef(
      key: 'indian',
      label: 'Indian',
      code: 'IN',
      words: ['indian', 'india', 'hindi', 'bollywood', 'tamil', 'telugu',
        'punjabi', 'urdu', 'pakistan', 'pakistani', 'malayalam', 'kannada',
        'bengali', 'bangla'],
      codes: [],
    ),
    LanguageDef(
      key: 'korean',
      label: 'Korean',
      code: 'KR',
      words: ['korean', 'korea', 'kdrama', 'hallyu'],
      codes: ['kr', 'ko'],
    ),
    LanguageDef(
      key: 'japanese',
      label: 'Japanese',
      code: 'JP',
      words: ['japanese', 'japan', 'nihon', 'nippon'],
      codes: ['jp', 'ja'],
    ),
    LanguageDef(
      key: 'chinese',
      label: 'Chinese',
      code: 'ZH',
      words: ['chinese', 'china', 'mandarin', 'cantonese', 'taiwan',
        'taiwanese', 'hongkong'],
      codes: ['zh', 'cn'],
    ),
    LanguageDef(
      key: 'vietnamese',
      label: 'Vietnamese',
      code: 'VI',
      words: ['vietnamese', 'vietnam'],
      codes: ['vi'],
    ),
    LanguageDef(
      key: 'thai',
      label: 'Thai',
      code: 'TH',
      words: ['thailand', 'thai'],
      codes: ['th'],
    ),
    LanguageDef(
      key: 'indonesian',
      label: 'Indonesian / Malay',
      code: 'ID',
      words: ['indonesia', 'indonesian', 'malaysia', 'malaysian', 'melayu'],
      codes: ['id'],
    ),
    LanguageDef(
      key: 'filipino',
      label: 'Filipino',
      code: 'PH',
      words: ['filipino', 'philippines', 'tagalog', 'pinoy'],
      codes: ['ph'],
    ),
    LanguageDef(
      key: 'dutch',
      label: 'Dutch',
      code: 'NL',
      words: ['dutch', 'netherlands', 'holland', 'nederland', 'flemish',
        'vlaams'],
      codes: ['nl'],
    ),
    LanguageDef(
      key: 'greek',
      label: 'Greek',
      code: 'EL',
      words: ['greek', 'greece', 'hellenic', 'ellinika'],
      codes: [],
    ),
    LanguageDef(
      key: 'polish',
      label: 'Polish',
      code: 'PL',
      words: ['polish', 'poland', 'polski', 'polska'],
      codes: ['pl'],
    ),
    LanguageDef(
      key: 'romanian',
      label: 'Romanian',
      code: 'RO',
      // 'roman' excluded — collides with the "Romance" genre.
      words: ['romanian', 'romania', 'romana', 'romaneste'],
      codes: ['ro'],
    ),
    LanguageDef(
      key: 'bulgarian',
      label: 'Bulgarian',
      code: 'BG',
      words: ['bulgarian', 'bulgaria', 'bulgariya', 'balgarski'],
      codes: ['bg'],
    ),
    LanguageDef(
      key: 'czech',
      label: 'Czech',
      code: 'CS',
      words: ['czech', 'cesky', 'ceska', 'cestina'],
      codes: [],
    ),
    LanguageDef(
      key: 'slovak',
      label: 'Slovak',
      code: 'SK',
      words: ['slovak', 'slovakia', 'slovensky', 'slovenska'],
      codes: [],
    ),
    LanguageDef(
      key: 'hungarian',
      label: 'Hungarian',
      code: 'HU',
      words: ['hungarian', 'hungary', 'magyar'],
      codes: ['hu'],
    ),
    LanguageDef(
      key: 'ukrainian',
      label: 'Ukrainian',
      code: 'UA',
      words: ['ukrainian', 'ukraine', 'ukrain', 'ukraina'],
      codes: [],
    ),
    LanguageDef(
      key: 'albanian',
      label: 'Albanian',
      code: 'AL',
      words: ['albanian', 'albania', 'shqip'],
      codes: [],
    ),
    LanguageDef(
      key: 'balkan',
      label: 'Ex-Yu / Balkan',
      code: 'EX-YU',
      words: ['balkan', 'exyu', 'serbia', 'serbian', 'srpski', 'croatia',
        'croatian', 'hrvatski', 'bosnia', 'bosnian', 'macedonia', 'macedonian',
        'slovenia', 'slovenian', 'montenegro'],
      codes: [],
    ),
    LanguageDef(
      key: 'swedish',
      label: 'Swedish',
      code: 'SV',
      words: ['swedish', 'sweden', 'svenska', 'svensk', 'sverige'],
      codes: [],
    ),
    LanguageDef(
      key: 'danish',
      label: 'Danish',
      code: 'DA',
      words: ['danish', 'denmark', 'dansk', 'danmark'],
      codes: [],
    ),
    LanguageDef(
      key: 'norwegian',
      label: 'Norwegian',
      code: 'NO',
      words: ['norwegian', 'norway', 'norsk', 'norge'],
      codes: [],
    ),
    LanguageDef(
      key: 'finnish',
      label: 'Finnish',
      code: 'FI',
      words: ['finnish', 'finland', 'suomi'],
      codes: [],
    ),
    LanguageDef(
      key: 'icelandic',
      label: 'Icelandic',
      code: 'IS',
      // 'island' excluded — common English word.
      words: ['icelandic', 'iceland', 'islenska'],
      codes: [],
    ),
  ];

  static final Map<String, LanguageDef> _byKey = {
    for (final d in definitions) d.key: d,
  };

  /// Languages pre-checked by default ("English and Arabic should be checked at
  /// all times" — applied as the default selection wherever present).
  static const Set<String> defaultKeys = {'arabic', 'english'};

  // ── Non-Latin script detection ─────────────────────────────────────────────
  // Built from code points (no literal glyphs in source).
  static String _r(int lo, int hi) =>
      '${String.fromCharCode(lo)}-${String.fromCharCode(hi)}';
  // Arabic + Arabic Supplement.
  static final RegExp _arabicScript = RegExp('[${_r(0x0600, 0x06FF)}${_r(0x0750, 0x077F)}]');
  static final RegExp _hebrewScript = RegExp('[${_r(0x0590, 0x05FF)}]');
  static final RegExp _greekScript = RegExp('[${_r(0x0370, 0x03FF)}]');

  // ── Diacritic folding (é→e, ñ→n, ü→u, ß→ss, …) so "Québec"→"quebec". ─────────
  static const Map<String, String> _fold = {
    'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a',
    'ă': 'a', 'ą': 'a',
    'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ĕ': 'e', 'ė': 'e',
    'ę': 'e', 'ě': 'e',
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i', 'ĭ': 'i', 'į': 'i',
    'ı': 'i',
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o', 'ō': 'o',
    'ŏ': 'o', 'ő': 'o',
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u', 'ŭ': 'u', 'ů': 'u',
    'ű': 'u', 'ų': 'u',
    'ç': 'c', 'ć': 'c', 'ĉ': 'c', 'ċ': 'c', 'č': 'c',
    'ñ': 'n', 'ń': 'n', 'ņ': 'n', 'ň': 'n',
    'ś': 's', 'ŝ': 's', 'ş': 's', 'š': 's', 'ș': 's',
    'ź': 'z', 'ż': 'z', 'ž': 'z',
    'ğ': 'g', 'ĝ': 'g', 'ġ': 'g', 'ģ': 'g',
    'ý': 'y', 'ÿ': 'y',
    'ß': 'ss',
  };

  static String _normalize(String s) {
    final lower = s.toLowerCase();
    final sb = StringBuffer();
    for (final ch in lower.split('')) {
      sb.write(_fold[ch] ?? ch);
    }
    return sb.toString();
  }

  /// Word-boundary regex for a code: preceded/followed by a non-letter (or
  /// string boundary). Built once per code and cached.
  static final Map<String, RegExp> _codeRe = {};
  static RegExp _re(String code) => _codeRe.putIfAbsent(
        code,
        () => RegExp('(^|[^a-z])${RegExp.escape(code)}(\$|[^a-z])'),
      );

  /// Returns the canonical language key for [categoryName], or `null` when the
  /// name carries no language marker (a genre / uncategorized list that should
  /// always be shown).
  static String? detect(String categoryName) {
    final name = categoryName.trim();
    if (name.isEmpty) return null;

    // 1. Non-Latin scripts are unambiguous strong signals.
    if (_arabicScript.hasMatch(name)) return 'arabic';
    if (_hebrewScript.hasMatch(name)) return 'hebrew';
    if (_greekScript.hasMatch(name)) return 'greek';

    final n = _normalize(name);

    // 2. Descriptive words (substring) — beat short codes.
    for (final def in definitions) {
      for (final w in def.words) {
        if (n.contains(w)) return def.key;
      }
    }
    // 3. Short codes (word-boundary), only if no descriptive word matched.
    for (final def in definitions) {
      for (final c in def.codes) {
        if (_re(c).hasMatch(n)) return def.key;
      }
    }
    return null;
  }

  static LanguageDef? defFor(String key) => _byKey[key];

  static String labelFor(String key) => _byKey[key]?.label ?? key;

  static String codeFor(String key) => _byKey[key]?.code ?? key.toUpperCase();

  /// The distinct languages that actually appear across [categories], returned
  /// in the registry's priority order (so the popup list is stable + sensible).
  /// This is what powers the "auto-detect" language list.
  static List<String> languagesPresent(Iterable<LiveCategory> categories) {
    final found = <String>{};
    for (final c in categories) {
      final k = detect(c.categoryName);
      if (k != null) found.add(k);
    }
    return [
      for (final d in definitions)
        if (found.contains(d.key)) d.key,
    ];
  }

  /// Given the categories the user can see and their [selected] languages,
  /// returns the set of category IDs that should be **hidden** — i.e. those
  /// whose detected language is not in [selected]. Categories with no language
  /// marker are never blocked.
  static Set<String> blockedCategoryIds(
    Iterable<LiveCategory> categories,
    Set<String> selected,
  ) {
    final blocked = <String>{};
    for (final c in categories) {
      final lang = detect(c.categoryName);
      if (lang != null && !selected.contains(lang)) {
        blocked.add(c.categoryId);
      }
    }
    return blocked;
  }

  /// The sensible default selection for a freshly-detected [present] list:
  /// Arabic + English when present, otherwise everything (so a playlist with
  /// neither never starts out hiding all its tagged content).
  static Set<String> defaultSelectionFor(List<String> present) {
    final base = present.where(defaultKeys.contains).toSet();
    return base.isNotEmpty ? base : present.toSet();
  }
}
