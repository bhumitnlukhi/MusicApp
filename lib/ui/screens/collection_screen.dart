import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/catalog.dart';
import '../../data/models.dart';
import '../../data/music_repository.dart';
import '../../state/library_controller.dart';
import '../../state/player_controller.dart';
import '../widgets/common.dart';
import '../widgets/mini_player.dart';
import '../widgets/motion.dart';
import '../widgets/track_tile.dart';
import 'library_screen.dart';

/// What a [CollectionScreen] shows.
sealed class CollectionSource {
  const CollectionSource();
}

class MixSource extends CollectionSource {
  const MixSource(this.mix);
  final Mix mix;
}

class AlbumSource extends CollectionSource {
  const AlbumSource(this.albumId);
  final String albumId;
}

class PlaylistSource extends CollectionSource {
  const PlaylistSource(this.playlistId);
  final String playlistId;
}

class LikedSource extends CollectionSource {
  const LikedSource();
}

/// Everything the header + list needs, regardless of source.
class _CollectionData {
  const _CollectionData({
    required this.title,
    required this.subtitle,
    required this.coverUrl,
    required this.tracks,
    this.isAlbum = false,
    this.album,
    this.playlist,
  });

  final String title;
  final String subtitle;
  final String coverUrl;
  final List<Track> tracks;
  final bool isAlbum;
  final AlbumSummary? album;
  final UserPlaylist? playlist;
}

/// Light track-list screen used for mixes, albums, user playlists and
/// Liked Songs (the "Chill Vibes" / "After Hours" screens in the design).
class CollectionScreen extends StatelessWidget {
  const CollectionScreen({
    super.key,
    required this.source,
    this.embedded = false,
  });

  final CollectionSource source;

  /// True when shown as a bottom-nav tab: no back button, and the shell
  /// already provides the mini player.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return ThemedScreen(
      dark: false,
      child: Scaffold(
        bottomNavigationBar: embedded
            ? null
            : const SafeArea(top: false, child: MiniPlayer()),
        body: SafeArea(
          bottom: false,
          child: switch (source) {
            MixSource(:final mix) => AsyncView<List<Track>>(
              load: () => context.read<MusicRepository>().mixTracks(mix),
              builder: (_, tracks) => _CollectionBody(
                showBack: !embedded,
                data: _CollectionData(
                  title: mix.title,
                  subtitle: 'Public Playlist  •  ${tracks.length} songs',
                  coverUrl: tracks.firstOrNull?.imageUrl ?? '',
                  tracks: tracks,
                ),
              ),
            ),
            AlbumSource(:final albumId) => AsyncView<AlbumDetails>(
              load: () => context.read<MusicRepository>().album(albumId),
              builder: (_, album) => _CollectionBody(
                showBack: !embedded,
                data: _CollectionData(
                  title: album.summary.title,
                  subtitle: [
                    album.summary.artist,
                    'Album',
                    album.summary.year,
                  ].where((s) => s.isNotEmpty).join('  •  '),
                  coverUrl: album.summary.imageUrl,
                  tracks: album.tracks,
                  isAlbum: true,
                  album: album.summary,
                ),
              ),
            ),
            PlaylistSource(:final playlistId) => Consumer<LibraryController>(
              builder: (context, library, _) {
                final playlist = library.playlist(playlistId);
                if (playlist == null) {
                  return const MessageView(
                    icon: Icons.queue_music_rounded,
                    title: 'Playlist not found',
                  );
                }
                return _CollectionBody(
                  showBack: !embedded,
                  data: _CollectionData(
                    title: playlist.name,
                    subtitle:
                        'Your Playlist  •  ${playlist.tracks.length} songs',
                    coverUrl: playlist.tracks.firstOrNull?.imageUrl ?? '',
                    tracks: playlist.tracks,
                    playlist: playlist,
                  ),
                );
              },
            ),
            LikedSource() => Consumer<LibraryController>(
              builder: (context, library, _) => _CollectionBody(
                showBack: !embedded,
                data: _CollectionData(
                  title: 'Liked Songs',
                  subtitle: '${library.liked.length} songs',
                  coverUrl: library.liked.firstOrNull?.imageUrl ?? '',
                  tracks: library.liked,
                ),
              ),
            ),
          },
        ),
      ),
    );
  }
}

class _CollectionBody extends StatefulWidget {
  const _CollectionBody({required this.data, required this.showBack});

  final _CollectionData data;
  final bool showBack;

  @override
  State<_CollectionBody> createState() => _CollectionBodyState();
}

class _CollectionBodyState extends State<_CollectionBody> {
  final _scroll = ScrollController();

  /// Scroll offset (negative while overscrolling at the top).
  double get _offset => _scroll.hasClients ? _scroll.offset : 0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final showBack = widget.showBack;
    final p = context.palette;
    final player = context.watch<PlayerController>();
    final library = context.watch<LibraryController>();
    final tracks = data.tracks;

    // Is this collection what's playing right now?
    final current = player.current;
    final isThisPlaying =
        current != null &&
        tracks.any((t) => t.id == current.id) &&
        player.isPlaying;

    return Stack(
      children: [
        // The cover's colors washed across the top, fading as you scroll.
        if (data.coverUrl.isNotEmpty)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 420,
            child: AnimatedBuilder(
              animation: _scroll,
              builder: (context, child) => Opacity(
                opacity: (1 - _offset / 360).clamp(0.0, 1.0),
                child: child,
              ),
              child: _CoverWash(url: data.coverUrl),
            ),
          ),
        CustomScrollView(
          controller: _scroll,
          slivers: [
            SliverToBoxAdapter(
              child: Row(
                children: [
                  const SizedBox(width: 4),
                  if (showBack)
                    IconBtn(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      tooltip: 'Back',
                      onTap: () => Navigator.pop(context),
                    )
                  else
                    const SizedBox(height: 40),
                  const Spacer(),
                  if (data.album != null)
                    IconBtn(
                      library.isAlbumSaved(data.album!.id)
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      tooltip: 'Save album',
                      onTap: () => library.toggleSaveAlbum(data.album!),
                    ),
                  if (data.playlist != null)
                    IconBtn(
                      Icons.more_horiz_rounded,
                      tooltip: 'Playlist options',
                      onTap: () => showPlaylistMenu(context, data.playlist!),
                    ),
                  if (tracks.isNotEmpty)
                    IconBtn(
                      Icons.shuffle_rounded,
                      tooltip: 'Shuffle play',
                      onTap: () => player.shufflePlay(tracks),
                    ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: Center(
                child: AnimatedBuilder(
                  animation: _scroll,
                  builder: (context, child) {
                    // Scrolling up tips the cover back in 3D and fades it;
                    // pulling down past the top grows it.
                    final o = _offset;
                    final progress = (o / 280).clamp(0.0, 1.0);
                    final stretch = 1 + math.max(0.0, -o) / 500;
                    final s = stretch * (1 - progress * 0.25);
                    return Opacity(
                      opacity: 1 - progress * 0.8,
                      child: Transform(
                        alignment: Alignment.bottomCenter,
                        transform: Motion.perspective()
                          ..translateByDouble(0, math.max(0.0, o) * 0.45, 0, 1)
                          ..rotateX(-progress * 0.9)
                          ..scaleByDouble(s, s, 1, 1),
                        child: child,
                      ),
                    );
                  },
                  child: Entrance(
                    offset: 40,
                    child: Container(
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.28),
                            blurRadius: 32,
                            spreadRadius: -4,
                            offset: const Offset(0, 18),
                          ),
                        ],
                      ),
                      child: Artwork(
                        url: data.coverUrl,
                        size: 220,
                        radius: 12,
                        icon: data.playlist != null || data.album == null
                            ? Icons.queue_music_rounded
                            : Icons.album_rounded,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.ui(
                              24,
                              weight: FontWeight.w800,
                              color: p.fg,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            data.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.ui(12, color: p.muted),
                          ),
                        ],
                      ),
                    ),
                    if (tracks.isNotEmpty)
                      RoundPlayButton(
                        size: 54,
                        playing: isThisPlaying,
                        onTap: () {
                          if (current != null &&
                              tracks.any((t) => t.id == current.id)) {
                            player.togglePlay();
                          } else {
                            player.playTracks(tracks);
                          }
                        },
                      ),
                  ],
                ),
              ),
            ),
            if (tracks.isEmpty)
              const SliverToBoxAdapter(
                child: MessageView(
                  icon: Icons.music_note_rounded,
                  title: 'No songs yet',
                  subtitle: 'Use "Add to playlist" from any song\'s menu.',
                ),
              )
            else
              SliverList.builder(
                itemCount: tracks.length,
                itemBuilder: (context, i) {
                  final t = tracks[i];
                  return Entrance(
                    index: i,
                    child: TrackTile(
                      track: t,
                      number: '${i + 1}',
                      showArtwork: !data.isAlbum,
                      subtitle: data.isAlbum
                          ? formatDuration(t.duration)
                          : null,
                      onTap: () => player.playTracks(tracks, index: i),
                      onRemove: data.playlist == null
                          ? null
                          : () => library.removeFromPlaylist(
                              data.playlist!.id,
                              t.id,
                            ),
                    ),
                  );
                },
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ],
    );
  }
}

/// Heavily blurred cover fading into the page — gives every album and
/// playlist its own color mood on the light screen.
class _CoverWash extends StatelessWidget {
  const _CoverWash({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final bg = context.palette.bg;
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          BlurredArt(url: url, opacity: 0.55),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  bg.withValues(alpha: 0.1),
                  bg.withValues(alpha: 0.6),
                  bg,
                ],
                stops: const [0, 0.6, 1],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
