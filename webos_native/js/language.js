/* language.js — category-name → language classifier (port of the Flutter
   CategoryLanguage). Powers the content-language filter on webOS. */
(function () {
  'use strict';
  var W = window.W;

  // [key, label, code, words(substring), codes(word-boundary)]
  var DEFS = [
    ['arabic', 'Arabic', 'AR',
      ['arabic', 'arab', 'arabe', 'arabia', 'arabiya', 'lebanon', 'lebanese', 'palestine', 'palestinian', 'egypt', 'egyptian', 'syria', 'syrian', 'iraq', 'iraqi', 'jordan', 'jordanian', 'saudi', 'emirates', 'kuwait', 'qatar', 'bahrain', 'yemen', 'yemeni', 'morocco', 'moroccan', 'algeria', 'algerian', 'tunisia', 'tunisian', 'libya', 'libyan', 'sudan', 'sudanese', 'khaleeji', 'maghreb', 'levant', 'rotana', 'shahid', 'quran', 'koran', 'islamic', 'ramadan'],
      ['ar', 'ksa', 'uae', 'mbc', 'osn', 'oman']],
    ['english', 'English', 'EN', ['english', 'britain', 'british', 'america', 'american', 'ireland', 'irish'], ['en', 'eng', 'uk', 'us', 'usa', 'au']],
    ['french', 'French', 'FR', ['french', 'france', 'francais', 'francaise', 'francophone', 'quebec', 'quebecois'], ['fr']],
    ['german', 'German', 'DE', ['german', 'germany', 'deutsch', 'deutsche', 'deutschland', 'austria', 'austrian'], ['de']],
    ['spanish', 'Spanish', 'ES', ['spanish', 'spain', 'espanol', 'espana', 'castellano', 'latino', 'mexico', 'mexican'], ['es']],
    ['italian', 'Italian', 'IT', ['italian', 'italy', 'italia', 'italiano'], ['it']],
    ['portuguese', 'Portuguese', 'PT', ['portuguese', 'portugal', 'portugues', 'brasil', 'brazil', 'brazilian'], ['pt', 'br']],
    ['turkish', 'Turkish', 'TR', ['turkish', 'turkey', 'turk', 'turkce', 'turkiye'], ['tr']],
    ['russian', 'Russian', 'RU', ['russian', 'russia', 'russain', 'russe', 'rossiya'], ['ru']],
    ['persian', 'Persian', 'FA', ['persian', 'iranian', 'farsi', 'parsi'], ['fa', 'ir', 'iran']],
    ['kurdish', 'Kurdish', 'KU', ['kurdish', 'kurd', 'kurdistan', 'kurmanji', 'sorani'], []],
    ['hebrew', 'Hebrew', 'HE', ['hebrew', 'ivrit', 'israel', 'israeli'], []],
    ['indian', 'Indian', 'IN', ['indian', 'india', 'hindi', 'bollywood', 'tamil', 'telugu', 'punjabi', 'urdu', 'pakistan', 'pakistani', 'malayalam', 'kannada', 'bengali', 'bangla'], ['in', 'hi']],
    ['korean', 'Korean', 'KR', ['korean', 'korea', 'kdrama', 'hallyu'], ['kr', 'ko']],
    ['japanese', 'Japanese', 'JP', ['japanese', 'japan', 'nihon', 'nippon'], ['jp', 'ja']],
    ['chinese', 'Chinese', 'ZH', ['chinese', 'china', 'mandarin', 'cantonese', 'taiwan', 'taiwanese', 'hongkong'], ['zh', 'cn']],
    ['vietnamese', 'Vietnamese', 'VI', ['vietnamese', 'vietnam'], ['vi']],
    ['thai', 'Thai', 'TH', ['thailand', 'thai'], ['th']],
    ['indonesian', 'Indonesian / Malay', 'ID', ['indonesia', 'indonesian', 'malaysia', 'malaysian', 'melayu'], ['id']],
    ['filipino', 'Filipino', 'PH', ['filipino', 'philippines', 'tagalog', 'pinoy'], ['ph']],
    ['dutch', 'Dutch', 'NL', ['dutch', 'netherlands', 'holland', 'nederland', 'flemish', 'vlaams'], ['nl']],
    ['greek', 'Greek', 'EL', ['greek', 'greece', 'hellenic', 'ellinika'], []],
    ['polish', 'Polish', 'PL', ['polish', 'poland', 'polski', 'polska'], ['pl']],
    ['romanian', 'Romanian', 'RO', ['romanian', 'romania', 'romana', 'romaneste'], ['ro']],
    ['bulgarian', 'Bulgarian', 'BG', ['bulgarian', 'bulgaria', 'bulgariya', 'balgarski'], ['bg']],
    ['czech', 'Czech', 'CS', ['czech', 'cesky', 'ceska', 'cestina'], []],
    ['slovak', 'Slovak', 'SK', ['slovak', 'slovakia', 'slovensky', 'slovenska'], []],
    ['hungarian', 'Hungarian', 'HU', ['hungarian', 'hungary', 'magyar'], ['hu']],
    ['ukrainian', 'Ukrainian', 'UA', ['ukrainian', 'ukraine', 'ukrain', 'ukraina'], []],
    ['albanian', 'Albanian', 'AL', ['albanian', 'albania', 'shqip'], []],
    ['balkan', 'Ex-Yu / Balkan', 'EX-YU', ['balkan', 'exyu', 'serbia', 'serbian', 'srpski', 'croatia', 'croatian', 'hrvatski', 'bosnia', 'bosnian', 'macedonia', 'macedonian', 'slovenia', 'slovenian', 'montenegro'], []],
    ['swedish', 'Swedish', 'SV', ['swedish', 'sweden', 'svenska', 'svensk', 'sverige'], []],
    ['danish', 'Danish', 'DA', ['danish', 'denmark', 'dansk', 'danmark'], []],
    ['norwegian', 'Norwegian', 'NO', ['norwegian', 'norway', 'norsk', 'norge'], []],
    ['finnish', 'Finnish', 'FI', ['finnish', 'finland', 'suomi'], []],
    ['icelandic', 'Icelandic', 'IS', ['icelandic', 'iceland', 'islenska'], []]
  ];

  var DEFAULT_KEYS = { arabic: 1, english: 1 };

  function R(lo, hi) { return String.fromCharCode(lo) + '-' + String.fromCharCode(hi); }
  var arabicScript = new RegExp('[' + R(0x0600, 0x06FF) + R(0x0750, 0x077F) + ']');
  var hebrewScript = new RegExp('[' + R(0x0590, 0x05FF) + ']');
  var greekScript = new RegExp('[' + R(0x0370, 0x03FF) + ']');

  var FOLD = { 'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a', 'ă': 'a', 'ą': 'a', 'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ė': 'e', 'ę': 'e', 'ě': 'e', 'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i', 'į': 'i', 'ı': 'i', 'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o', 'ō': 'o', 'ő': 'o', 'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u', 'ů': 'u', 'ű': 'u', 'ç': 'c', 'ć': 'c', 'č': 'c', 'ñ': 'n', 'ń': 'n', 'ň': 'n', 'ś': 's', 'š': 's', 'ş': 's', 'ș': 's', 'ź': 'z', 'ż': 'z', 'ž': 'z', 'ğ': 'g', 'ý': 'y', 'ÿ': 'y', 'ß': 'ss' };
  function normalize(s) {
    s = s.toLowerCase();
    var out = '';
    for (var i = 0; i < s.length; i++) { var c = s[i]; out += FOLD[c] || c; }
    return out;
  }

  // Codes match only as a LEADING prefix ("DE :", "IN |", "US -", "[FR]"),
  // optionally after leading punctuation — never mid-string. This catches real
  // language tags while ignoring the Romance "de" ("Filmes de Terror") and the
  // English "in" ("Movies in HD").
  var codeRe = {};
  function reFor(code) {
    if (!codeRe[code]) codeRe[code] = new RegExp('^[^a-z]*' + code + '(?![a-z])');
    return codeRe[code];
  }

  function detect(name) {
    if (!name) return null;
    name = ('' + name).replace(/^\s+|\s+$/g, '');
    if (!name) return null;
    if (arabicScript.test(name)) return 'arabic';
    if (hebrewScript.test(name)) return 'hebrew';
    if (greekScript.test(name)) return 'greek';
    var n = normalize(name);
    var i, j;
    for (i = 0; i < DEFS.length; i++) { var ws = DEFS[i][3]; for (j = 0; j < ws.length; j++) if (n.indexOf(ws[j]) !== -1) return DEFS[i][0]; }
    for (i = 0; i < DEFS.length; i++) { var cs = DEFS[i][4]; for (j = 0; j < cs.length; j++) if (reFor(cs[j]).test(n)) return DEFS[i][0]; }
    return null;
  }

  var labels = {}, codes = {};
  for (var i = 0; i < DEFS.length; i++) { labels[DEFS[i][0]] = DEFS[i][1]; codes[DEFS[i][0]] = DEFS[i][2]; }

  W.Lang = {
    detect: detect,
    labelFor: function (k) { return labels[k] || k; },
    codeFor: function (k) { return codes[k] || k.toUpperCase(); },
    // distinct languages present across [cats] (each {category_name}), priority order
    present: function (cats) {
      var found = {};
      for (var i = 0; i < cats.length; i++) { var k = detect(cats[i].category_name); if (k) found[k] = 1; }
      var out = [];
      for (var d = 0; d < DEFS.length; d++) if (found[DEFS[d][0]]) out.push(DEFS[d][0]);
      return out;
    },
    // set (object map) of blocked category_id given cats + selected[] languages
    blocked: function (cats, selected) {
      var sel = {}; for (var s = 0; s < selected.length; s++) sel[selected[s]] = 1;
      var out = {};
      for (var i = 0; i < cats.length; i++) {
        var lang = detect(cats[i].category_name);
        if (lang && !sel[lang]) out[cats[i].category_id] = 1;
      }
      return out;
    },
    defaultSelection: function (present) {
      var base = present.filter(function (k) { return DEFAULT_KEYS[k]; });
      return base.length ? base : present.slice();
    }
  };
})();
