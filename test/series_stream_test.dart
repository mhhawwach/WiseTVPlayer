import 'package:flutter_test/flutter_test.dart';
import 'package:wisetv_player/data/models/series_stream.dart';

SeriesStream _parse(Map<String, dynamic> extra) =>
    SeriesStream.fromJson({'series_id': 1, 'name': 'Show', ...extra});

void main() {
  group('SeriesStream.backdropPath', () {
    test('takes the first URL of the list Xtream sends', () {
      expect(
        _parse({
          'backdrop_path': ['http://x/a.jpg', 'http://x/b.jpg'],
        }).backdropPath,
        'http://x/a.jpg',
      );
    });

    test('empty list means no backdrop', () {
      expect(_parse({'backdrop_path': <String>[]}).backdropPath, '');
    });

    test('recovers a list cached as its string form', () {
      expect(_parse({'backdrop_path': '[http://x/a.jpg]'}).backdropPath,
          'http://x/a.jpg');
    });

    test('keeps a plain URL', () {
      expect(_parse({'backdrop_path': 'http://x/a.jpg'}).backdropPath,
          'http://x/a.jpg');
    });
  });

  group('SeriesStream.episodeRunTime', () {
    test('minutes pass through', () {
      expect(_parse({'episode_run_time': '45'}).episodeRunTime, 45);
    });

    test('seconds are converted to minutes', () {
      expect(_parse({'episode_run_time': '1200'}).episodeRunTime, 20);
    });

    test('missing or implausible values are hidden', () {
      expect(_parse({'episode_run_time': '0'}).episodeRunTime, 0);
      expect(_parse({}).episodeRunTime, 0);
      expect(_parse({'episode_run_time': '99999'}).episodeRunTime, 0);
    });
  });
}
