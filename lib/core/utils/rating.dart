// ─────────────────────────────────────────────────────────────────────────────
// Rating sanitization.
//
// Xtream panels are supposed to send a 0–10 `rating`, but feeds in the wild
// send junk — vote counts, 0–100 scales, or plain garbage like "602". Those
// values would otherwise render as "602.0" and (worse) dominate any
// rating-sorted list like the Home hero banner.
//
// We treat a rating as valid ONLY when it parses to a number in (0, 10].
// Anything else (empty, unparseable, <= 0, or > 10) is "no rating" → null.
// ─────────────────────────────────────────────────────────────────────────────

/// Parsed 0–10 rating, or null when missing / out of range / garbage.
double? parseRating(String? raw) {
  if (raw == null) return null;
  final v = double.tryParse(raw.trim());
  if (v == null || v <= 0 || v > 10) return null;
  return v;
}

/// One-decimal label (e.g. "6.5"), or null when there is no valid rating.
String? formatRatingLabel(String? raw) => parseRating(raw)?.toStringAsFixed(1);
