import 'dart:convert';

import 'package:dart_des/dart_des.dart';
import 'package:dio/dio.dart';

import 'models.dart';
import 'music_repository.dart';

/// Cloud stream repository providing search, catalog, and metadata.
class CloudMediaRepository implements MusicRepository {
  CloudMediaRepository({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: _decodeBaseUrl(),
                queryParameters: {
                  '_format': 'json',
                  '_marker': '0',
                  'ctx': 'wap6dot0',
                },
                responseType: ResponseType.json,
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 15),
              ),
            );

  final Dio _dio;
  final Map<String, Future<Object?>> _cache = {};

  static const _k = '38346591';

  static String _decodeBaseUrl() {
    return utf8.decode(base64Decode('aHR0cHM6Ly93d3cuamlvc2Fhdm4uY29tL2FwaS5waHA='));
  }

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

  Future<Map<String, dynamic>> _request({
    required String call,
    bool isAPIv4 = false,
    Map<String, dynamic>? queryParameters,
  }) async {
    final res = await _dio.get<dynamic>(
      '',
      queryParameters: {
        if (isAPIv4) 'api_version': 4,
        '__call': call,
        ...?queryParameters,
      },
      options: Options(
        responseType: ResponseType.plain,
        headers: {
          'cookie': 'L=english; gdpr_acceptance=true; DL=english',
        },
      ),
    );

    final raw = res.data;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is String) {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    }
    return <String, dynamic>{};
  }

  @override
  Future<List<Track>> searchTracks(String query, {int limit = 20}) =>
      _cached('tracks:$query:$limit', () async {
        final res = await _request(
          call: 'search.getResults',
          queryParameters: {'q': query, 'p': 0, 'n': limit},
        );
        final results = res['results'];
        if (results is! List) return [];
        return results
            .whereType<Map<String, dynamic>>()
            .map(_mapTrack)
            .whereType<Track>()
            .toList();
      });

  @override
  Future<List<ArtistSummary>> searchArtists(String query, {int limit = 10}) =>
      _cached('artists:$query:$limit', () async {
        final res = await _request(
          call: 'search.getArtistResults',
          queryParameters: {'q': query, 'p': 0, 'n': limit},
        );
        final results = res['results'];
        if (results is! List) return [];
        return results
            .whereType<Map<String, dynamic>>()
            .map(_mapArtistSummary)
            .toList();
      });

  @override
  Future<List<AlbumSummary>> searchAlbums(String query, {int limit = 10}) =>
      _cached('albums:$query:$limit', () async {
        final res = await _request(
          call: 'search.getAlbumResults',
          queryParameters: {'q': query, 'p': 0, 'n': limit},
        );
        final results = res['results'];
        if (results is! List) return [];
        return results
            .whereType<Map<String, dynamic>>()
            .map(_mapAlbumSummary)
            .toList();
      });

  @override
  Future<ArtistSummary?> findArtist(String name) async {
    final results = await searchArtists(name, limit: 1);
    return results.isEmpty ? null : results.first;
  }

  @override
  Future<ArtistDetails> artist(String id) => _cached('artist:$id', () async {
        final (details, songsRes, albumsRes) = await (
          _request(
            call: 'artist.getArtistPageDetails',
            isAPIv4: true,
            queryParameters: {'artistId': id},
          ),
          _request(
            call: 'artist.getArtistMoreSong',
            queryParameters: {'artistId': id, 'page': 0},
          ),
          _request(
            call: 'artist.getArtistMoreAlbum',
            isAPIv4: true,
            queryParameters: {'artistId': id, 'page': 0},
          ),
        ).wait;

        final rawTopSongs = songsRes['topSongs'];
        final songsList = (rawTopSongs is Map && rawTopSongs['songs'] is List)
            ? rawTopSongs['songs'] as List
            : (details['topSongs'] is List ? details['topSongs'] as List : []);

        final tracks = songsList
            .whereType<Map<String, dynamic>>()
            .map((item) {
              if (item.containsKey('more_info')) {
                return _mapTrackFromMoreInfo(item);
              }
              return _mapTrack(item);
            })
            .whereType<Track>()
            .toList();

        final rawTopAlbums = albumsRes['topAlbums'];
        final albumsList = (rawTopAlbums is Map && rawTopAlbums['albums'] is List)
            ? rawTopAlbums['albums'] as List
            : (details['topAlbums'] is List ? details['topAlbums'] as List : []);

        final albums = albumsList
            .whereType<Map<String, dynamic>>()
            .map(_mapAlbumSummary)
            .toList();

        final summary = _mapArtistSummary(details);

        return ArtistDetails(
          summary: summary,
          followers: int.tryParse(details['follower_count']?.toString() ?? ''),
          bio: _parseBio(details['bio']?.toString()),
          language: details['dominantLanguage']?.toString() ?? details['dominant_language']?.toString(),
          topTracks: _uniqueByTitle(tracks),
          albums: albums,
        );
      });

  @override
  Future<AlbumDetails> album(String id) => _cached('album:$id', () async {
        final res = await _request(
          call: 'content.getAlbumDetails',
          queryParameters: {'albumid': id},
        );

        final rawSongs = res['songs'];
        final tracks = rawSongs is List
            ? rawSongs
                .whereType<Map<String, dynamic>>()
                .map(_mapTrack)
                .whereType<Track>()
                .toList()
            : <Track>[];

        var summary = _mapAlbumSummary(res);
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

  // ---- mapping helpers ------------------------------------------------------

  Track? _mapTrack(Map<String, dynamic> json) {
    final encUrl = json['encrypted_media_url']?.toString() ??
        (json['more_info'] is Map ? json['more_info']['encrypted_media_url']?.toString() : null);

    if (encUrl == null || encUrl.isEmpty) return null;

    final streamUrl = _decryptStreamUrl(encUrl);
    if (streamUrl == null || streamUrl.isEmpty) return null;

    final title = json['song']?.toString() ?? json['title']?.toString() ?? '';
    final albumTitle = json['album']?.toString() ??
        (json['more_info'] is Map ? json['more_info']['album']?.toString() ?? '' : '');
    final albumId = json['albumid']?.toString() ??
        (json['more_info'] is Map ? json['more_info']['album_id']?.toString() ?? '' : '');

    final primaryArtists = json['primary_artists']?.toString() ?? '';
    final featuredArtists = json['featured_artists']?.toString() ?? '';
    final artist = primaryArtists.isNotEmpty ? primaryArtists : featuredArtists;

    final rawImage = json['image']?.toString();
    final imageUrl = _bestImage(rawImage);

    final durationSec = int.tryParse(json['duration']?.toString() ?? '') ?? 0;
    final primaryArtistsId = json['primary_artists_id']?.toString() ?? '';
    final artistId = primaryArtistsId.split(',').first.trim().nullIfEmpty;
    final playCount = int.tryParse(json['play_count']?.toString() ?? '');

    return Track(
      id: json['id']?.toString() ?? '',
      title: _clean(title),
      artist: _clean(artist),
      album: _clean(albumTitle),
      albumId: albumId,
      imageUrl: imageUrl,
      streamUrl: streamUrl,
      duration: Duration(seconds: durationSec),
      artistId: artistId,
      playCount: playCount,
    );
  }

  Track? _mapTrackFromMoreInfo(Map<String, dynamic> json) {
    final more = json['more_info'] as Map<String, dynamic>?;
    if (more == null) return _mapTrack(json);

    final encUrl = more['encrypted_media_url']?.toString();
    if (encUrl == null || encUrl.isEmpty) return null;

    final streamUrl = _decryptStreamUrl(encUrl);
    if (streamUrl == null || streamUrl.isEmpty) return null;

    final title = json['title']?.toString() ?? json['song']?.toString() ?? '';
    final albumTitle = more['album']?.toString() ?? '';
    final albumId = more['album_id']?.toString() ?? '';

    String artist = '';
    String primaryArtistsId = '';
    final artistMap = more['artistMap'];
    if (artistMap is Map) {
      final primary = artistMap['primary_artists'];
      if (primary is List && primary.isNotEmpty) {
        artist = primary.map((e) => e is Map ? e['name'] : '').where((e) => e.isNotEmpty).join(', ');
        primaryArtistsId = primary.map((e) => e is Map ? e['id'] : '').where((e) => e.isNotEmpty).join(', ');
      }
    }
    if (artist.isEmpty) {
      artist = more['singers']?.toString() ?? json['primary_artists']?.toString() ?? '';
    }

    final rawImage = json['image']?.toString();
    final imageUrl = _bestImage(rawImage);
    final durationSec = int.tryParse(more['duration']?.toString() ?? json['duration']?.toString() ?? '') ?? 0;
    final artistId = primaryArtistsId.split(',').first.trim().nullIfEmpty;
    final playCount = int.tryParse(json['play_count']?.toString() ?? '');

    return Track(
      id: json['id']?.toString() ?? '',
      title: _clean(title),
      artist: _clean(artist),
      album: _clean(albumTitle),
      albumId: albumId,
      imageUrl: imageUrl,
      streamUrl: streamUrl,
      duration: Duration(seconds: durationSec),
      artistId: artistId,
      playCount: playCount,
    );
  }

  ArtistSummary _mapArtistSummary(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? json['artistId']?.toString() ?? '';
    final name = json['name']?.toString() ?? '';
    final rawImage = json['image']?.toString();
    return ArtistSummary(
      id: id,
      name: _clean(name),
      imageUrl: _bestImage(rawImage),
    );
  }

  AlbumSummary _mapAlbumSummary(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? json['albumid']?.toString() ?? '';
    final title = json['title']?.toString() ?? json['name']?.toString() ?? '';
    final year = json['year']?.toString() ?? '';
    final rawImage = json['image']?.toString();

    String artist = json['primary_artists']?.toString() ?? '';
    if (artist.isEmpty && json['more_info'] is Map) {
      final more = json['more_info'] as Map<String, dynamic>;
      final artistMap = more['artist_map'] ?? more['artistMap'];
      if (artistMap is Map && artistMap['primary_artists'] is List) {
        final primary = artistMap['primary_artists'] as List;
        artist = primary.map((e) => e is Map ? e['name']?.toString() ?? '' : '').where((e) => e.isNotEmpty).take(2).join(', ');
      }
    }

    return AlbumSummary(
      id: id,
      title: _clean(title),
      artist: _clean(artist),
      year: year,
      imageUrl: _bestImage(rawImage),
    );
  }

  List<Track> _uniqueByTitle(Iterable<Track> tracks) {
    final seen = <String>{};
    return tracks.where((t) => seen.add(t.title.toLowerCase())).toList();
  }

  String _bestImage(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.contains('150x150')) {
      return url.replaceAll('150x150', '500x500');
    }
    if (url.contains('50x50')) {
      return url.replaceAll('50x50', '500x500');
    }
    return url;
  }

  String? _decryptStreamUrl(String encUrl) {
    try {
      final encryptedBytes = base64Decode(encUrl);
      final cipher = DES(
        key: _k.codeUnits,
        mode: DESMode.ECB,
        paddingType: DESPaddingType.PKCS7,
      );
      final decrypted = cipher.decrypt(encryptedBytes);
      final url = utf8.decode(decrypted);
      return url.replaceAll('_96', '_320');
    } catch (_) {
      return null;
    }
  }

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

