import 'package:dio/dio.dart';

import 'models.dart';

/// Lyrics from LRCLIB (https://lrclib.net) — a free, open lyrics database
/// that also provides time-synced (LRC) lyrics. No API key needed.
class LyricsRepository {
  LyricsRepository({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://lrclib.net/api',
              headers: {'User-Agent': 'PulseMusicApp/1.0 (learning project)'},
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ),
          );

  final Dio _dio;
  final Map<String, Future<Lyrics?>> _cache = {};

  /// Returns null when no lyrics exist for the track.
  Future<Lyrics?> fetch(Track track) {
    return _cache.putIfAbsent(track.id, () async {
      try {
        return await _fetch(track);
      } catch (_) {
        _cache.remove(track.id);
        rethrow;
      }
    });
  }

  Future<Lyrics?> _fetch(Track track) async {
    final artist = track.artist.split(',').first.trim();
    // Exact match first (title + artist + duration), then a looser search.
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/get',
        queryParameters: {
          'track_name': track.title,
          'artist_name': artist,
          if (track.duration > Duration.zero)
            'duration': track.duration.inSeconds,
        },
      );
      final lyrics = _parse(res.data);
      if (lyrics != null) return lyrics;
    } on DioException catch (e) {
      if (e.response?.statusCode != 404) rethrow;
    }

    final res = await _dio.get<List<dynamic>>(
      '/search',
      queryParameters: {'track_name': track.title, 'artist_name': artist},
    );
    for (final item in res.data ?? const []) {
      final lyrics = _parse(item as Map<String, dynamic>);
      if (lyrics != null) return lyrics;
    }
    return null;
  }

  Lyrics? _parse(Map<String, dynamic>? json) {
    if (json == null || json['instrumental'] == true) return null;
    final synced = json['syncedLyrics'] as String?;
    if (synced != null && synced.trim().isNotEmpty) {
      final lines = _parseLrc(synced);
      if (lines.isNotEmpty) return Lyrics(lines);
    }
    final plain = json['plainLyrics'] as String?;
    if (plain != null && plain.trim().isNotEmpty) {
      return Lyrics(
        plain.split('\n').map((l) => LyricLine(null, l.trim())).toList(),
      );
    }
    return null;
  }

  static final _lrcLine = RegExp(r'^\[(\d+):(\d+(?:\.\d+)?)\](.*)$');

  List<LyricLine> _parseLrc(String lrc) {
    final lines = <LyricLine>[];
    for (final raw in lrc.split('\n')) {
      final match = _lrcLine.firstMatch(raw.trim());
      if (match == null) continue;
      final minutes = int.parse(match.group(1)!);
      final seconds = double.parse(match.group(2)!);
      lines.add(
        LyricLine(
          Duration(milliseconds: ((minutes * 60 + seconds) * 1000).round()),
          match.group(3)!.trim(),
        ),
      );
    }
    return lines;
  }
}
