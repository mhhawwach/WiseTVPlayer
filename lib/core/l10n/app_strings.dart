import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/locale_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AppStrings — all user-visible text in the app.
//
// Use via ref.watch(stringsProvider) in any ConsumerWidget/ConsumerState,
// or via AppStrings.of(context) when a BuildContext is available.
// ─────────────────────────────────────────────────────────────────────────────

abstract class AppStrings {
  const AppStrings();

  // ── Navigation ─────────────────────────────────────────────────────────────
  String get home;
  String get liveTV;
  String get movies;
  String get series;
  String get search;
  String get favourites;
  String get settings;

  // ── Home / Category screens ────────────────────────────────────────────────
  String get allCategories;
  String get noMoviesFound;
  String get noSeriesFound;
  String get noChannelsFound;
  String get noFavouritesFound;
  String get noHistoryFound;
  String get loading;

  // ── Search ─────────────────────────────────────────────────────────────────
  String get searchMoviesHint;
  String get searchSeriesHint;
  String get searchChannelsHint;
  String get searchHint;

  // ── Sort ───────────────────────────────────────────────────────────────────
  String get sortDefault;
  String get sortNameAZ;
  String get sortNameZA;
  String get sortRating;
  String get sortRecentlyAdded;
  String get sortByYear;

  // ── Player ─────────────────────────────────────────────────────────────────
  String get live;
  String get audioSubtitles;
  String get programmeGuide;
  String get statsForNerds;
  String get pictureInPicture;
  String get prev;
  String get next;

  // ── Profiles ───────────────────────────────────────────────────────────────
  String get profiles;
  String get manageProfiles;
  String get addProfile;
  String get editProfile;
  String get deleteProfile;
  String get deleteProfileConfirm;
  String get profilesHint;
  String get switchProfile;
  String get delete;

  // ── Settings ───────────────────────────────────────────────────────────────
  String get appearance;
  String get sPlaylists;
  String get managePlaylists;
  String get player;
  String get liveTVPlayer;
  String get moviesSeriesPlayer;
  String get parentalControls;
  String get pinLockedCategories;
  String get manageCategories;
  String get manageCategoriesSubtitle;
  String get cache;
  String get watchHistory;
  String get clearHistory;
  String get historyCleared;
  String get clearContentCache;
  String get clearContentCacheSubtitle;
  String get contentCacheCleared;
  String get sLanguage;
  String get textSize;
  String get layout;
  String get layoutAuto;
  String get layoutTv;
  String get layoutPhone;
  String get wallpaper;
  String get about;
  String get version;
  String get account;
  String get diagnostics;
  String get diagnosticsSubtitle;

  // ── Wallpaper labels ───────────────────────────────────────────────────────
  String get wallpaperNone;
  String get wallpaperIptv;
  String get wallpaperCosmic;
  String get wallpaperCinema;
  String get wallpaperAurora;
  String get wallpaperNeon;

  // ── Language labels ────────────────────────────────────────────────────────
  String get langEnglish;
  String get langArabic;

  // ── Player settings ────────────────────────────────────────────────────────
  String get playerAuto;
  String get playerHardware;
  String get playerSoftware;

  // ── Series detail ──────────────────────────────────────────────────────────
  String get season;
  String get episode;
  String get episodes;
  String get plot;
  String get cast;
  String get director;
  String get genre;
  String get rating;
  String get duration;

  // ── Trailer ────────────────────────────────────────────────────────────────
  String get watchTrailer;

  // ── Next episode countdown ──────────────────────────────────────────────────
  String get nextEpisode;
  String get playingNextIn; // "Playing next in"

  // ── Account info ───────────────────────────────────────────────────────────
  String get accountInfo;
  String get accountStatus;
  String get accountExpiry;
  String get accountConnections;
  String get accountServer;
  String get accountTimezone;
  String get accountActive;
  String get accountExpired;
  String get accountTrial;

  // ── Misc ───────────────────────────────────────────────────────────────────
  String get retry;
  String get close;
  String get confirm;
  String get cancel;
  String get refresh;
  String get refreshingContent;

  // ── Provider helper ────────────────────────────────────────────────────────
  static AppStrings of(BuildContext context) {
    // Falls back gracefully if no provider is available higher up.
    return const _EnStrings();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// English
// ─────────────────────────────────────────────────────────────────────────────

class _EnStrings extends AppStrings {
  const _EnStrings();

  @override String get home => 'Home';
  @override String get liveTV => 'Live TV';
  @override String get movies => 'Movies';
  @override String get series => 'Series';
  @override String get search => 'Search';
  @override String get favourites => 'Favourites';
  @override String get settings => 'Settings';

  @override String get allCategories => 'All';
  @override String get noMoviesFound => 'No movies found';
  @override String get noSeriesFound => 'No series found';
  @override String get noChannelsFound => 'No channels found';
  @override String get noFavouritesFound => 'No favourites yet';
  @override String get noHistoryFound => 'No history yet';
  @override String get loading => 'Loading…';

  @override String get searchMoviesHint => 'Search movies…';
  @override String get searchSeriesHint => 'Search series…';
  @override String get searchChannelsHint => 'Search channels…';
  @override String get searchHint => 'Search…';

  @override String get sortDefault => 'Default';
  @override String get sortNameAZ => 'A → Z';
  @override String get sortNameZA => 'Z → A';
  @override String get sortRating => 'Rating ↓';
  @override String get sortRecentlyAdded => 'Recently Added';
  @override String get sortByYear => 'Newest First';

  @override String get live => 'LIVE';
  @override String get audioSubtitles => 'Audio & Subtitles';
  @override String get programmeGuide => 'Programme Guide';
  @override String get statsForNerds => 'Stats for Nerds';
  @override String get pictureInPicture => 'Picture in Picture';
  @override String get prev => 'Prev';
  @override String get next => 'Next';

  @override String get profiles            => 'Profiles';
  @override String get manageProfiles      => 'Manage Profiles';
  @override String get addProfile          => 'Add Profile';
  @override String get editProfile         => 'Edit Profile';
  @override String get deleteProfile       => 'Delete Profile';
  @override String get deleteProfileConfirm => 'Delete all data for';
  @override String get profilesHint        => 'Each profile has its own watch history, favourites & settings';
  @override String get switchProfile       => 'Switch Profile';
  @override String get delete              => 'Delete';

  @override String get appearance => 'Appearance';
  @override String get sPlaylists => 'Playlists';
  @override String get managePlaylists => 'Manage Playlists';
  @override String get player => 'Player';
  @override String get liveTVPlayer => 'Live TV Player';
  @override String get moviesSeriesPlayer => 'Movies & Series Player';
  @override String get parentalControls => 'Parental Controls';
  @override String get pinLockedCategories => 'PIN & Locked Categories';
  @override String get manageCategories => 'Manage Categories';
  @override String get manageCategoriesSubtitle => 'Hide, lock, or reorder categories';
  @override String get cache => 'Cache';
  @override String get watchHistory => 'Watch History';
  @override String get clearHistory => 'Clear Watch History';
  @override String get historyCleared => 'History cleared';
  @override String get clearContentCache => 'Clear Content Cache';
  @override String get clearContentCacheSubtitle =>
      'Force movies, series & categories to reload';
  @override String get contentCacheCleared => 'Content cache cleared';
  @override String get sLanguage => 'Language';
  @override String get textSize => 'Text Size';
  @override String get layout => 'Layout';
  @override String get layoutAuto => 'Auto';
  @override String get layoutTv => 'TV';
  @override String get layoutPhone => 'Phone';
  @override String get wallpaper => 'Wallpaper';
  @override String get about => 'About';
  @override String get version => 'v1.0.4';
  @override String get account => 'Account';
  @override String get diagnostics => 'Diagnostics';
  @override String get diagnosticsSubtitle => 'Device info & crash logs';

  @override String get wallpaperNone => 'None';
  @override String get wallpaperIptv => 'IPTV';
  @override String get wallpaperCosmic => 'Cosmic';
  @override String get wallpaperCinema => 'Cinema';
  @override String get wallpaperAurora => 'Aurora';
  @override String get wallpaperNeon => 'Neon';

  @override String get langEnglish => 'English';
  @override String get langArabic => 'Arabic';

  @override String get playerAuto => 'Auto';
  @override String get playerHardware => 'Hardware';
  @override String get playerSoftware => 'Software';

  @override String get season => 'Season';
  @override String get episode => 'Episode';
  @override String get episodes => 'Episodes';
  @override String get plot => 'Plot';
  @override String get cast => 'Cast';
  @override String get director => 'Director';
  @override String get genre => 'Genre';
  @override String get rating => 'Rating';
  @override String get duration => 'Duration';

  @override String get watchTrailer => 'Watch Trailer';

  @override String get nextEpisode => 'Next Episode';
  @override String get playingNextIn => 'Playing next in';

  @override String get accountInfo => 'Account Info';
  @override String get accountStatus => 'Status';
  @override String get accountExpiry => 'Expires';
  @override String get accountConnections => 'Connections';
  @override String get accountServer => 'Server';
  @override String get accountTimezone => 'Timezone';
  @override String get accountActive => 'Active';
  @override String get accountExpired => 'Expired';
  @override String get accountTrial => 'Trial';

  @override String get retry => 'Retry';
  @override String get close => 'Close';
  @override String get confirm => 'Confirm';
  @override String get cancel => 'Cancel';
  @override String get refresh => 'Refresh';
  @override String get refreshingContent => 'Refreshing content…';
}

// ─────────────────────────────────────────────────────────────────────────────
// Arabic  (العربية)
// ─────────────────────────────────────────────────────────────────────────────

class _ArStrings extends AppStrings {
  const _ArStrings();

  @override String get home => 'الرئيسية';
  @override String get liveTV => 'التلفزيون المباشر';
  @override String get movies => 'الأفلام';
  @override String get series => 'المسلسلات';
  @override String get search => 'البحث';
  @override String get favourites => 'المفضلة';
  @override String get settings => 'الإعدادات';

  @override String get allCategories => 'الكل';
  @override String get noMoviesFound => 'لا توجد أفلام';
  @override String get noSeriesFound => 'لا توجد مسلسلات';
  @override String get noChannelsFound => 'لا توجد قنوات';
  @override String get noFavouritesFound => 'لا توجد مفضلات بعد';
  @override String get noHistoryFound => 'لا يوجد سجل بعد';
  @override String get loading => 'جارٍ التحميل…';

  @override String get searchMoviesHint => 'ابحث عن أفلام…';
  @override String get searchSeriesHint => 'ابحث عن مسلسلات…';
  @override String get searchChannelsHint => 'ابحث عن قنوات…';
  @override String get searchHint => 'بحث…';

  @override String get sortDefault => 'الترتيب الافتراضي';
  @override String get sortNameAZ => 'أ ← ي';
  @override String get sortNameZA => 'ي ← أ';
  @override String get sortRating => 'التقييم ↓';
  @override String get sortRecentlyAdded => 'المُضاف حديثاً';
  @override String get sortByYear => 'الأحدث أولاً';

  @override String get live => 'مباشر';
  @override String get audioSubtitles => 'الصوت والترجمة';
  @override String get programmeGuide => 'دليل البرامج';
  @override String get statsForNerds => 'إحصائيات تقنية';
  @override String get pictureInPicture => 'صورة داخل صورة';
  @override String get prev => 'السابق';
  @override String get next => 'التالي';

  @override String get profiles            => 'الملفات الشخصية';
  @override String get manageProfiles      => 'إدارة الملفات الشخصية';
  @override String get addProfile          => 'إضافة ملف شخصي';
  @override String get editProfile         => 'تعديل الملف الشخصي';
  @override String get deleteProfile       => 'حذف الملف الشخصي';
  @override String get deleteProfileConfirm => 'حذف جميع بيانات';
  @override String get profilesHint        => 'لكل ملف شخصي سجل مشاهدة ومفضلة وإعدادات خاصة';
  @override String get switchProfile       => 'تبديل الملف الشخصي';
  @override String get delete              => 'حذف';

  @override String get appearance => 'المظهر';
  @override String get sPlaylists => 'قوائم التشغيل';
  @override String get managePlaylists => 'إدارة قوائم التشغيل';
  @override String get player => 'المشغّل';
  @override String get liveTVPlayer => 'مشغّل التلفزيون المباشر';
  @override String get moviesSeriesPlayer => 'مشغّل الأفلام والمسلسلات';
  @override String get parentalControls => 'الرقابة الأبوية';
  @override String get pinLockedCategories => 'الرمز والفئات المقفلة';
  @override String get manageCategories => 'إدارة الفئات';
  @override String get manageCategoriesSubtitle => 'إخفاء أو قفل أو إعادة ترتيب الفئات';
  @override String get cache => 'ذاكرة التخزين المؤقت';
  @override String get watchHistory => 'سجل المشاهدة';
  @override String get clearHistory => 'مسح سجل المشاهدة';
  @override String get historyCleared => 'تم مسح السجل';
  @override String get clearContentCache => 'مسح ذاكرة المحتوى';
  @override String get clearContentCacheSubtitle =>
      'إعادة تحميل الأفلام والمسلسلات والفئات';
  @override String get contentCacheCleared => 'تم مسح ذاكرة المحتوى';
  @override String get sLanguage => 'اللغة';
  @override String get textSize => 'حجم النص';
  @override String get layout => 'التخطيط';
  @override String get layoutAuto => 'تلقائي';
  @override String get layoutTv => 'تلفزيون';
  @override String get layoutPhone => 'هاتف';
  @override String get wallpaper => 'خلفية الشاشة';
  @override String get about => 'حول التطبيق';
  @override String get version => 'الإصدار 1.0.4';
  @override String get account => 'الحساب';
  @override String get diagnostics => 'التشخيص';
  @override String get diagnosticsSubtitle => 'معلومات الجهاز وسجلات الأعطال';

  @override String get wallpaperNone => 'لا شيء';
  @override String get wallpaperIptv => 'IPTV';
  @override String get wallpaperCosmic => 'كوني';
  @override String get wallpaperCinema => 'سينما';
  @override String get wallpaperAurora => 'أورورا';
  @override String get wallpaperNeon => 'نيون';

  @override String get langEnglish => 'الإنجليزية';
  @override String get langArabic => 'العربية';

  @override String get playerAuto => 'تلقائي';
  @override String get playerHardware => 'معالج الجهاز';
  @override String get playerSoftware => 'معالج البرنامج';

  @override String get season => 'موسم';
  @override String get episode => 'حلقة';
  @override String get episodes => 'الحلقات';
  @override String get plot => 'القصة';
  @override String get cast => 'الممثلون';
  @override String get director => 'المخرج';
  @override String get genre => 'النوع';
  @override String get rating => 'التقييم';
  @override String get duration => 'المدة';

  @override String get watchTrailer => 'مشاهدة الإعلان';

  @override String get nextEpisode => 'الحلقة التالية';
  @override String get playingNextIn => 'التشغيل التالي خلال';

  @override String get accountInfo => 'معلومات الحساب';
  @override String get accountStatus => 'الحالة';
  @override String get accountExpiry => 'ينتهي في';
  @override String get accountConnections => 'الاتصالات';
  @override String get accountServer => 'الخادم';
  @override String get accountTimezone => 'المنطقة الزمنية';
  @override String get accountActive => 'نشط';
  @override String get accountExpired => 'منتهي';
  @override String get accountTrial => 'تجريبي';

  @override String get retry => 'إعادة المحاولة';
  @override String get close => 'إغلاق';
  @override String get confirm => 'تأكيد';
  @override String get cancel => 'إلغاء';
  @override String get refresh => 'تحديث';
  @override String get refreshingContent => 'جارٍ تحديث المحتوى…';
}

// ─────────────────────────────────────────────────────────────────────────────
// Riverpod provider
// ─────────────────────────────────────────────────────────────────────────────

final stringsProvider = Provider<AppStrings>((ref) {
  final locale = ref.watch(localeProvider);
  return locale == AppLocale.ar ? const _ArStrings() : const _EnStrings();
});
