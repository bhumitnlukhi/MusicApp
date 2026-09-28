import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models.dart';

/// The user's own stuff — liked songs, playlists, followed artists, saved
/// albums, recently played — persisted locally with shared_preferences.
class LibraryController extends ChangeNotifier {
  LibraryController._(this._prefs) {
    _liked = _readList(_kLiked, Track.fromJson);
    _playlists = _readList(_kPlaylists, UserPlaylist.fromJson);
    _artists = _readList(_kArtists, ArtistSummary.fromJson);
    _albums = _readList(_kAlbums, AlbumSummary.fromJson);
    _recent = _readList(_kRecent, Track.fromJson);
  }

  static Future<LibraryController> load() async =>
      LibraryController._(await SharedPreferences.getInstance());

  static const _kLiked = 'liked';
  static const _kPlaylists = 'playlists';
  static const _kArtists = 'artists';
  static const _kAlbums = 'albums';
  static const _kRecent = 'recent';
  static const _kOnboarded = 'onboarded';
  static const _maxRecent = 20;

  final SharedPreferences _prefs;

  late List<Track> _liked;
  late List<UserPlaylist> _playlists;
  late List<ArtistSummary> _artists;
  late List<AlbumSummary> _albums;
  late List<Track> _recent;

  List<Track> get liked => List.unmodifiable(_liked);
  List<UserPlaylist> get playlists => List.unmodifiable(_playlists);
  List<ArtistSummary> get followedArtists => List.unmodifiable(_artists);
  List<AlbumSummary> get savedAlbums => List.unmodifiable(_albums);
  List<Track> get recent => List.unmodifiable(_recent);

  bool get onboarded => _prefs.getBool(_kOnboarded) ?? false;

  Future<void> completeOnboarding() => _prefs.setBool(_kOnboarded, true);

  // ---- liked songs ---------------------------------------------------------

  bool isLiked(String trackId) => _liked.any((t) => t.id == trackId);

  /// Returns true if the track is now liked.
  bool toggleLike(Track track) {
    final wasLiked = isLiked(track.id);
    if (wasLiked) {
      _liked.removeWhere((t) => t.id == track.id);
    } else {
      _liked.insert(0, track);
    }
    _save(_kLiked, _liked.map((t) => t.toJson()));
    return !wasLiked;
  }

  // ---- playlists -----------------------------------------------------------

  UserPlaylist? playlist(String id) =>
      _playlists.where((p) => p.id == id).firstOrNull;

  UserPlaylist createPlaylist(String name) {
    final playlist = UserPlaylist(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim(),
      tracks: const [],
    );
    _playlists.insert(0, playlist);
    _savePlaylists();
    return playlist;
  }

  void renamePlaylist(String id, String name) =>
      _updatePlaylist(id, (p) => p.copyWith(name: name.trim()));

  void deletePlaylist(String id) {
    _playlists.removeWhere((p) => p.id == id);
    _savePlaylists();
  }

  /// Returns false if the track was already in the playlist.
  bool addToPlaylist(String playlistId, Track track) {
    final p = playlist(playlistId);
    if (p == null || p.tracks.any((t) => t.id == track.id)) return false;
    _updatePlaylist(
      playlistId,
      (p) => p.copyWith(tracks: [...p.tracks, track]),
    );
    return true;
  }

  void removeFromPlaylist(String playlistId, String trackId) => _updatePlaylist(
    playlistId,
    (p) => p.copyWith(tracks: p.tracks.where((t) => t.id != trackId).toList()),
  );

  void _updatePlaylist(String id, UserPlaylist Function(UserPlaylist) update) {
    final i = _playlists.indexWhere((p) => p.id == id);
    if (i == -1) return;
    _playlists[i] = update(_playlists[i]);
    _savePlaylists();
  }

  void _savePlaylists() =>
      _save(_kPlaylists, _playlists.map((p) => p.toJson()));

  // ---- artists & albums ----------------------------------------------------

  bool isFollowing(String artistId) => _artists.any((a) => a.id == artistId);

  void toggleFollow(ArtistSummary artist) {
    if (isFollowing(artist.id)) {
      _artists.removeWhere((a) => a.id == artist.id);
    } else {
      _artists.insert(0, artist);
    }
    _save(_kArtists, _artists.map((a) => a.toJson()));
  }

  bool isAlbumSaved(String albumId) => _albums.any((a) => a.id == albumId);

  void toggleSaveAlbum(AlbumSummary album) {
    if (isAlbumSaved(album.id)) {
      _albums.removeWhere((a) => a.id == album.id);
    } else {
      _albums.insert(0, album);
    }
    _save(_kAlbums, _albums.map((a) => a.toJson()));
  }

  // ---- recently played -----------------------------------------------------

  void addRecent(Track track) {
    _recent
      ..removeWhere((t) => t.id == track.id)
      ..insert(0, track);
    if (_recent.length > _maxRecent) {
      _recent.removeRange(_maxRecent, _recent.length);
    }
    _save(_kRecent, _recent.map((t) => t.toJson()));
  }

  // ---- persistence ---------------------------------------------------------

  List<T> _readList<T>(String key, T Function(Map<String, dynamic>) fromJson) {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Discarding corrupt "$key" data: $e');
      return [];
    }
  }

  void _save(String key, Iterable<Map<String, dynamic>> items) {
    _prefs.setString(key, jsonEncode(items.toList()));
    notifyListeners();
  }
}
