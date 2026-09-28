import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models.dart';
import '../../state/library_controller.dart';
import '../../state/player_controller.dart';
import '../navigation.dart';
import '../widgets/common.dart';
import '../widgets/track_tile.dart';

/// Library tab (dark): playlists, followed artists, saved albums, liked songs.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  static const _tabs = ['Playlists', 'Artists', 'Albums', 'Liked'];
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
                child: switch (_tab) {
                  0 => const _PlaylistsTab(),
                  1 => const _ArtistsTab(),
                  2 => const _AlbumsTab(),
                  _ => const _LikedTab(),
                },
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
              borderRadius: BorderRadius.circular(4),
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
              borderRadius: BorderRadius.circular(4),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF4B5BD6),
                  Color(0xFFB45CC9),
                  Color(0xFFF08A7E),
                ],
              ),
            ),
            child: const Icon(
              Icons.favorite_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          title: 'Liked Songs',
          subtitle: '${library.liked.length} songs',
          onTap: context.openLiked,
        ),
        for (final playlist in library.playlists)
          _LibraryRow(
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
        for (final artist in artists)
          _LibraryRow(
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
        for (final album in albums)
          _LibraryRow(
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
      itemBuilder: (context, i) => TrackTile(
        track: liked[i],
        onTap: () =>
            context.read<PlayerController>().playTracks(liked, index: i),
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
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      onLongPress: onMore,
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
                    style: AppText.ui(14, weight: FontWeight.w500, color: p.fg),
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
              IconBtn(Icons.more_horiz_rounded, tooltip: 'More', onTap: onMore),
          ],
        ),
      ),
    );
  }
}
