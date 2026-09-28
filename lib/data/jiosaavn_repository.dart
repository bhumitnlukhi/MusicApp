import 'dart:convert';

import 'package:jiosaavn/jiosaavn.dart';

import 'models.dart';
import 'music_repository.dart';

/// [MusicRepository] backed by the unofficial `jiosaavn` package.
///
/// For learning/personal use only — these are JioSaavn's private endpoints.
class JioSaavnRepository implements MusicRepository {
  JioSaavnRepository({JioSaavnClient? client})
    : _client = client ?? JioSaavnClient();

  final JioSaavnClient _client;

  /// Request cache so revisiting a screen doesn't refetch. Failed requests
  /// are evicted so the next visit retries.
  final Map<String, Future<Object?>> _cache = {};

  Future<T> _cached<T>(String key, Future<T> Function() load) {
    final existing = _cache[key];
    if (existing != null) return existing.then((v) => v as T);
    final future = load();
    _cache[key] = future;
    future.then<void>(
      (_) {},
      onError: (Object _) {
        _cache.remove(key);
      },
    );
    return future;
  }

  @override
  Future<List<Track>> searchTracks(String query, {int limit = 20}) =>
      _cached('tracks:$query:$limit', () async {
        final res = await _client.search.songs(query, limit: limit);
        return res.results.map(_track).whereType<Track>().toList();
      });

  @override
  Future<List<ArtistSummary>> searchArtists(String query, {int limit = 10}) =>
      _cached('artists:$query:$limit', () async {
        final res = await _client.search.artists(query, limit: limit);
        return res.results.map(_artistSummary).toList();
      });

  @override
  Future<List<AlbumSummary>> searchAlbums(String query, {int limit = 10}) =>
      _cached('albums:$query:$limit', () async {
        final res = await _client.search.albums(query, limit: limit);
        return res.results.map(_albumSummary).toList();
      });

  @override
  Future<ArtistSummary?> findArtist(String name) async {
    final results = await searchArtists(name, limit: 1);
    return results.isEmpty ? null : results.first;
  }

  @override
  Future<ArtistDetails> artist(String id) => _cached('artist:$id', () async {
    final (details, songs, albums) = await (
      _client.artists.detailsById(id),
      _client.artists.artistSongs(id, page: 0),
      _client.artists.artistAlbums(id),
    ).wait;
    return ArtistDetails(
      summary: _artistSummary(details),
      followers: int.tryParse(details.followerCount ?? ''),
      bio: _parseBio(details.bio),
      language: details.dominantLanguage,
      topTracks: _uniqueByTitle(songs.results.map(_track).whereType<Track>()),
      albums: albums.results.map(_albumSummary).toList(),
    );
  });

  @override
  Future<AlbumDetails> album(String id) => _cached('album:$id', () async {
    final res = await _client.albums.detailsById(id);
    final tracks = res.songs.map(_track).whereType<Track>().toList();
    var summary = _albumSummary(res);
    // Some albums have no artist map — fall back to the first track's.
    if (summary.artist.isEmpty && tracks.isNotEmpty) {
      summary = AlbumSummary(
        id: summary.id,
        title: summary.title,
        artist: tracks.first.artist.split(',').first,
        year: summary.year,
        imageUrl: summary.imageUrl,
      );
    }
    return AlbumDetails(summary: summary, tracks: tracks);
  });

  // ---- mapping -------------------------------------------------------------

  /// Returns null for songs without a playable stream.
  Track? _track(SongResponse s) {
    final streams = s.downloadUrl;
    if (streams == null || streams.isEmpty) return null;
    final artist = s.primaryArtists.isNotEmpty
        ? s.primaryArtists
        : s.featuredArtists;
    return Track(
      id: s.id,
      title: _clean(s.name ?? ''),
      artist: _clean(artist),
      album: _clean(s.album.name),
      albumId: s.album.id,
      imageUrl: _bestImage(s.image),
      streamUrl: streams.last.link, // highest quality (320kbps)
      duration: Duration(seconds: int.tryParse(s.duration) ?? 0),
      artistId: s.primaryArtistsId.split(',').first.trim().nullIfEmpty,
      playCount: int.tryParse(s.playCount ?? ''),
    );
  }

  ArtistSummary _artistSummary(ArtistResponse a) => ArtistSummary(
    id: a.id,
    name: _clean(a.name),
    imageUrl: _bestImage(a.image),
  );

  AlbumSummary _albumSummary(AlbumResponse a) {
    final artists = a.primaryArtists.isNotEmpty ? a.primaryArtists : a.artists;
    return AlbumSummary(
      id: a.id,
      title: _clean(a.name),
      artist: _clean(artists.map((e) => e.name).take(2).join(', ')),
      year: a.year,
      imageUrl: _bestImage(a.image),
    );
  }

  /// The same song often appears once per album (single, deluxe, best-of…).
  List<Track> _uniqueByTitle(Iterable<Track> tracks) {
    final seen = <String>{};
    return tracks.where((t) => seen.add(t.title.toLowerCase())).toList();
  }

  String _bestImage(List<DownloadLink>? images) =>
      images == null || images.isEmpty ? '' : images.last.link;

  /// Artist bios come back as a JSON array of `{text, title}` sections.
  String? _parseBio(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List && decoded.isNotEmpty) {
        final first = decoded.first;
        if (first is Map && first['text'] is String) {
          return _clean(first['text'] as String);
        }
      }
      return null;
    } on FormatException {
      return _clean(raw);
    }
  }

  /// JioSaavn returns HTML-escaped strings ("Tum Hi Ho &amp; more").
  static String _clean(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#039;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .trim();
}

extension on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}
