import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models.dart';
import '../../state/library_controller.dart';
import '../../state/local_audio_controller.dart';
import '../../state/player_controller.dart';
import '../navigation.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';
import '../widgets/track_tile.dart';

/// Library tab (dark): playlists, followed artists, saved albums, liked songs.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  static const _tabs = ['Playlists', 'Device Audio', 'Artists', 'Albums', 'Liked'];
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return ThemedScreen(
      dark: true,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenHeader(
                label: '03',
                title: 'Your Library',
                actions: [
                  IconBtn(
                    Icons.shield_outlined,
                    tooltip: 'Privacy Policy',
                    onTap: context.openPrivacyPolicy,
                  ),
                  IconBtn(
                    Icons.add_rounded,
                    tooltip: 'New playlist',
                    onTap: () => showCreatePlaylistDialog(context),
                  ),
                ],
              ),
              PillTabs(
                tabs: _tabs,
                selected: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: AnimatedSwitcher(
                  duration: Motion.medium,
                  switchInCurve: Motion.decelerate,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0.06, 0),
                        end: Offset.zero,
                      ).animate(a),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(_tab),
                    child: switch (_tab) {
                      0 => const _PlaylistsTab(),
                      1 => const _DeviceAudioTab(),
                      2 => const _ArtistsTab(),
                      3 => const _AlbumsTab(),
                      _ => const _LikedTab(),
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaylistsTab extends StatelessWidget {
  const _PlaylistsTab();

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    final p = context.palette;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _LibraryRow(
          leading: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              border: Border.all(color: p.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.add_rounded, color: p.fg),
          ),
          title: 'Create Playlist',
          onTap: () => showCreatePlaylistDialog(context),
        ),
        _LibraryRow(
          leading: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              // The song's colors, so Liked Songs glows with the music.
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  p.accentDeep,
                  Color.lerp(p.accent, p.glow, 0.5)!,
                  p.glow,
                ],
              ),
            ),
            child: const Icon(
              Icons.favorite_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          index: 1,
          title: 'Liked Songs',
          subtitle: '${library.liked.length} songs',
          onTap: context.openLiked,
        ),
        for (final (i, playlist) in library.playlists.indexed)
          _LibraryRow(
            index: i + 2,
            leading: Artwork(
              url: playlist.tracks.firstOrNull?.imageUrl ?? '',
              size: 52,
              icon: Icons.queue_music_rounded,
            ),
            title: playlist.name,
            subtitle: '${playlist.tracks.length} songs',
            onTap: () => context.openPlaylist(playlist.id),
            onMore: () => _showPlaylistMenu(context, playlist),
          ),
        const SizedBox(height: 16),
        _LibraryRow(
          leading: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: p.surface,
              border: Border.all(color: p.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.shield_outlined, color: p.accentText, size: 22),
          ),
          title: 'Privacy Policy',
          subtitle: 'Zero data collection • 100% on-device',
          onTap: context.openPrivacyPolicy,
        ),
      ],
    );
  }
}

Future<void> showPlaylistMenu(BuildContext context, UserPlaylist playlist) =>
    _showPlaylistMenu(context, playlist);

Future<void> _showPlaylistMenu(BuildContext context, UserPlaylist playlist) {
  final library = context.read<LibraryController>();
  final player = context.read<PlayerController>();
  final screen = context;
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheet) {
      final p = sheet.palette;
      Widget action(IconData icon, String label, VoidCallback onTap) =>
          ListTile(
            leading: Icon(icon, color: p.fg),
            title: Text(label, style: AppText.ui(14, color: p.fg)),
            dense: true,
            onTap: () {
              Navigator.pop(sheet);
              onTap();
            },
          );
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (playlist.tracks.isNotEmpty)
              action(
                Icons.play_arrow_rounded,
                'Play',
                () => player.playTracks(playlist.tracks),
              ),
            action(
              Icons.edit_outlined,
              'Rename',
              () => showCreatePlaylistDialog(screen, renaming: playlist),
            ),
            action(Icons.delete_outline_rounded, 'Delete playlist', () async {
              final confirmed = await showDialog<bool>(
                context: screen,
                builder: (dialog) => AlertDialog(
                  title: Text(
                    'Delete "${playlist.name}"?',
                    style: AppText.ui(
                      16,
                      weight: FontWeight.w600,
                      color: dialog.palette.fg,
                    ),
                  ),
                  content: Text(
                    'This can\'t be undone.',
                    style: AppText.ui(14, color: dialog.palette.muted),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialog, false),
                      child: Text(
                        'Cancel',
                        style: AppText.ui(14, color: dialog.palette.muted),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(dialog, true),
                      child: Text(
                        'Delete',
                        style: AppText.ui(
                          14,
                          weight: FontWeight.w600,
                          color: const Color(0xFFE5484D),
                        ),
                      ),
                    ),
                  ],
                ),
              );
              if (confirmed == true) library.deletePlaylist(playlist.id);
            }),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

class _ArtistsTab extends StatelessWidget {
  const _ArtistsTab();

  @override
  Widget build(BuildContext context) {
    final artists = context.watch<LibraryController>().followedArtists;
    if (artists.isEmpty) {
      return const MessageView(
        icon: Icons.person_outline_rounded,
        title: 'No artists yet',
        subtitle: 'Tap Follow on an artist to see them here.',
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        for (final (i, artist) in artists.indexed)
          _LibraryRow(
            index: i,
            leading: Artwork(
              url: artist.imageUrl,
              size: 52,
              circle: true,
              icon: Icons.person_rounded,
            ),
            title: artist.name,
            subtitle: 'Artist',
            onTap: () => context.openArtist(artist.id),
          ),
      ],
    );
  }
}

class _AlbumsTab extends StatelessWidget {
  const _AlbumsTab();

  @override
  Widget build(BuildContext context) {
    final albums = context.watch<LibraryController>().savedAlbums;
    if (albums.isEmpty) {
      return const MessageView(
        icon: Icons.album_outlined,
        title: 'No saved albums',
        subtitle: 'Tap the heart on an album to save it.',
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        for (final (i, album) in albums.indexed)
          _LibraryRow(
            index: i,
            leading: Artwork(url: album.imageUrl, size: 52),
            title: album.title,
            subtitle: '${album.artist} · ${album.year}',
            onTap: () => context.openAlbum(album.id),
          ),
      ],
    );
  }
}

class _LikedTab extends StatelessWidget {
  const _LikedTab();

  @override
  Widget build(BuildContext context) {
    final liked = context.watch<LibraryController>().liked;
    if (liked.isEmpty) {
      return const MessageView(
        icon: Icons.favorite_border_rounded,
        title: 'Songs you like will appear here',
        subtitle: 'Tap the heart on any song to save it.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: liked.length,
      itemBuilder: (context, i) => Entrance(
        index: i,
        child: TrackTile(
          track: liked[i],
          onTap: () =>
              context.read<PlayerController>().playTracks(liked, index: i),
        ),
      ),
    );
  }
}

class _LibraryRow extends StatelessWidget {
  const _LibraryRow({
    required this.leading,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.onMore,
    this.index = 0,
  });

  /// Position in the list, for the staggered entrance.
  final int index;
  final Widget leading;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Entrance(
      index: index,
      child: Pressable(
        onTap: onTap,
        onLongPress: onMore,
        scale: 0.97,
        tilt: 0.05,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.ui(
                        14,
                        weight: FontWeight.w500,
                        color: p.fg,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.ui(11.5, color: p.muted),
                      ),
                    ],
                  ],
                ),
              ),
              if (onMore != null)
                IconBtn(
                  Icons.more_horiz_rounded,
                  tooltip: 'More',
                  onTap: onMore,
                ),
            ],
          ),
        ),
      ),
    );
  }
}


class _DeviceAudioTab extends StatelessWidget {
  const _DeviceAudioTab();

  @override
  Widget build(BuildContext context) {
    final local = context.watch<LocalAudioController>();
    final player = context.read<PlayerController>();
    final p = context.palette;

    if (local.isLoading) {
      return Center(
        child: CircularProgressIndicator(color: p.accentText),
      );
    }

    if (!local.hasPermission) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: p.isDark
                        ? AppColors.inkBorder
                        : AppColors.paperBorder.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.folder_open_rounded,
                    color: p.accentText,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'OFFLINE AUDIO FILES',
                  style: AppText.ui(
                    15,
                    weight: FontWeight.w700,
                    color: p.fg,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Melofy can play your local MP3, M4A, WAV, and FLAC audio files directly from device storage without internet.',
                  textAlign: TextAlign.center,
                  style: AppText.ui(13, color: p.muted, height: 1.5),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton.icon(
                    onPressed: local.requestAndLoad,
                    icon: const Icon(Icons.security_rounded, size: 18),
                    label: Text(
                      'Scan Device Audio',
                      style: AppText.ui(14, weight: FontWeight.w600),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: p.isDark ? AppColors.paper : AppColors.ink,
                      foregroundColor: p.isDark ? AppColors.ink : AppColors.paper,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (local.tracks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.audio_file_outlined, size: 54, color: p.muted),
              const SizedBox(height: 12),
              Text(
                'No Local Audio Files Found',
                style: AppText.ui(16, weight: FontWeight.w600, color: p.fg),
              ),
              const SizedBox(height: 6),
              Text(
                'Add MP3 or audio files to your Music or Download folder and tap refresh.',
                textAlign: TextAlign.center,
                style: AppText.ui(13, color: p.muted),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: local.loadTracks,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Row(
            children: [
              Text(
                '${local.count} AUDIO FILES',
                style: AppText.mono(11, color: p.muted, weight: FontWeight.w600),
              ),
              const Spacer(),
              Pressable(
                onTap: () => player.shufflePlay(local.tracks),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: p.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shuffle_rounded, size: 14, color: p.accentText),
                      const SizedBox(width: 6),
                      Text(
                        'Shuffle All',
                        style: AppText.ui(12, weight: FontWeight.w600, color: p.fg),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconBtn(
                Icons.refresh_rounded,
                tooltip: 'Re-scan',
                onTap: local.loadTracks,
              ),
            ],
          ),
        ),
        for (final (i, track) in local.tracks.indexed)
          TrackTile(
            number: '${i + 1}'.padLeft(2, '0'),
            track: track,
            onTap: () => player.playTracks(local.tracks, index: i),
          ),
      ],
    );
  }
}
