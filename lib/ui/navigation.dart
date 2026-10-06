import 'package:flutter/material.dart';

import '../data/models.dart';
import 'screens/artist_screen.dart';
import 'screens/collection_screen.dart';
import 'screens/lyrics_screen.dart';
import 'screens/now_playing_screen.dart';
import 'screens/queue_screen.dart';
import 'widgets/motion.dart';

/// One place for all screen-to-screen navigation.
extension AppNavigation on BuildContext {
  Future<void> _push(Widget screen) =>
      Navigator.of(this).push(MaterialPageRoute<void>(builder: (_) => screen));

  /// Full-screen player sheets rise from the bottom in 3D.
  Future<void> _pushUp(Widget screen) =>
      Navigator.of(this).push(SheetPageRoute<void>(builder: (_) => screen));

  Future<void> openArtist(String artistId) =>
      _push(ArtistScreen(artistId: artistId));

  Future<void> openAlbum(String albumId) =>
      _push(CollectionScreen(source: AlbumSource(albumId)));

  Future<void> openMix(Mix mix) =>
      _push(CollectionScreen(source: MixSource(mix)));

  Future<void> openPlaylist(String playlistId) =>
      _push(CollectionScreen(source: PlaylistSource(playlistId)));

  Future<void> openLiked() =>
      _push(const CollectionScreen(source: LikedSource()));

  Future<void> openNowPlaying() => _pushUp(const NowPlayingScreen());

  Future<void> openLyrics() => _pushUp(const LyricsScreen());

  Future<void> openQueue() => _pushUp(const QueueScreen());
}
