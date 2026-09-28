import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/data/catalog.dart';
import 'package:music_app/data/models.dart';
import 'package:music_app/data/music_repository.dart';
import 'package:music_app/ui/widgets/common.dart';

Track _t(String id, String title, String artist) => Track(
  id: id,
  title: title,
  artist: artist,
  album: '',
  albumId: '',
  imageUrl: '',
  streamUrl: 'https://example.com/$id.mp4',
  duration: const Duration(minutes: 3),
);

class _FakeRepo implements MusicRepository {
  _FakeRepo(this.results);

  final Map<String, List<Track>?> results;

  @override
  Future<List<Track>> searchTracks(String query, {int limit = 20}) async {
    final r = results[query];
    if (r == null) throw Exception('offline');
    return r.take(limit).toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('mixTracks', () {
    test('interleaves query results and drops duplicate songs', () async {
      final repo = _FakeRepo({
        'a': [_t('1', 'One', 'A'), _t('2', 'Two', 'A')],
        'b': [_t('3', 'Three', 'B'), _t('9', 'one', 'A')], // dup of "One"
      });
      const mix = Mix(id: 'm', title: 'M', queries: ['a', 'b']);

      final tracks = await repo.mixTracks(mix);

      expect(tracks.map((t) => t.id), ['1', '3', '2']);
    });

    test('tolerates one failing query', () async {
      final repo = _FakeRepo({
        'a': [_t('1', 'One', 'A')],
        'b': null,
      });
      const mix = Mix(id: 'm', title: 'M', queries: ['a', 'b']);

      expect((await repo.mixTracks(mix)).single.id, '1');
    });

    test('throws when every query fails', () {
      final repo = _FakeRepo({'a': null});
      const mix = Mix(id: 'm', title: 'M', queries: ['a']);

      expect(repo.mixTracks(mix), throwsException);
    });
  });

  test('Track survives a JSON round trip', () {
    final t = _t('1', 'One', 'A');
    final back = Track.fromJson(t.toJson());
    expect(back.id, t.id);
    expect(back.duration, t.duration);
  });

  test('formatters', () {
    expect(formatDuration(const Duration(seconds: 251)), '4:11');
    expect(formatCount(3243364), '3.2M');
    expect(formatCount(1280000000), '1.3B');
    expect(formatCount(950), '950');
  });
}
