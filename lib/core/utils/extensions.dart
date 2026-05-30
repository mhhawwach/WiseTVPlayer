extension StringX on String? {
  bool get isNullOrEmpty => this == null || this!.isEmpty;
  String get orEmpty => this ?? '';
  String get orNA => isNullOrEmpty ? 'N/A' : this!;

  /// Formats a Unix timestamp string to readable date
  String toReadableDate() {
    if (isNullOrEmpty) return '';
    final ts = int.tryParse(this!);
    if (ts == null) return this!;
    final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

extension IntX on int? {
  String get orZero => (this ?? 0).toString();
  String toMinutesDuration() {
    if (this == null) return '';
    final h = this! ~/ 60;
    final m = this! % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }
}

extension DoubleX on double? {
  String toRating() {
    if (this == null || this == 0) return '';
    return this!.toStringAsFixed(1);
  }
}

extension ListX<T> on List<T>? {
  bool get isNullOrEmpty => this == null || this!.isEmpty;
}
