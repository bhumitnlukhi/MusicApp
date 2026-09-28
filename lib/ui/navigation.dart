import 'package:flutter/material.dart';

import '../data/models.dart';
import 'screens/artist_screen.dart';
import 'screens/collection_screen.dart';
import 'screens/lyrics_screen.dart';
import 'screens/now_playing_screen.dart';
import 'screens/queue_screen.dart';

/// One place for all screen-to-screen navigation.
extension AppNavigation on BuildContext {
  Future<void> _push(Widget screen) =>
      Navigator.of(this).push(MaterialPageRoute<void>(builder: (_) => screen));

  /// Full-screen player sheets slide up from the bottom.
  Future<void> _pushUp(Widget screen) => Navigator.of(this).push(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, _, _) => screen,
      transitionsBuilder: (_, animation, _, child) => SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: child,
      ),
    ),
  );

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
