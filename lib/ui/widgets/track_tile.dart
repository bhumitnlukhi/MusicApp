import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models.dart';
import '../../state/library_controller.dart';
import '../../state/player_controller.dart';
import '../navigation.dart';
import 'common.dart';
import 'motion.dart';

/// A song row: optional number, artwork, title/subtitle and a "…" menu.
class TrackTile extends StatelessWidget {
  const TrackTile({
    super.key,
    required this.track,
    required this.onTap,
    this.number,
    this.showArtwork = true,
    this.subtitle,
    this.onRemove,
    this.trailing,
  });

  final Track track;
  final VoidCallback onTap;

  /// Leading index; zero-padded ("01") when [padNumber] is used by callers.
  final String? number;
  final bool showArtwork;

  /// Overrides the default subtitle (artist name).
  final String? subtitle;

  /// Adds "Remove from this playlist" to the menu.
  final VoidCallback? onRemove;

  /// Replaces the "…" menu button.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isCurrent = context.select<PlayerController, bool>(
      (c) => c.current?.id == track.id,
    );
    final playing = context.select<PlayerController, bool>(
      (c) => c.isPlaying && c.current?.id == track.id,
    );
    final titleColor = isCurrent ? p.accentText : p.fg;
    final highlight = p.isDark
        ? p.accent.withValues(alpha: 0.1)
        : AppColors.ink.withValues(alpha: 0.05);

    return Pressable(
      onTap: onTap,
      onLongPress: () => showTrackActions(context, track, onRemove: onRemove),
      scale: 0.98,
      tilt: 0.04,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
        decoration: BoxDecoration(
          color: isCurrent ? highlight : highlight.withValues(alpha: 0),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            if (number != null)
              SizedBox(
                width: 28,
                child: isCurrent
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: EqualizerBars(
                          playing: playing,
                          size: 14,
                          color: p.accentText,
                        ),
                      )
                    : Text(
                        number!,
                        style: AppText.ui(
                          12,
                          color: p.muted,
                          weight: FontWeight.w500,
                        ),
                      ),
              ),
            if (showArtwork) ...[
              Stack(
                alignment: Alignment.center,
                children: [
                  Artwork(url: track.imageUrl, size: 46, radius: 8),
                  // Playing indicator over the cover when there's no number.
                  if (number == null)
                    AnimatedOpacity(
                      opacity: isCurrent ? 1 : 0,
                      duration: Motion.medium,
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: isCurrent
                            ? EqualizerBars(
                                playing: playing,
                                size: 16,
                                color: p.isDark ? p.accent : AppColors.paper,
                              )
                            : null,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: Motion.medium,
                    style: AppText.ui(
                      14,
                      weight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                      color: titleColor,
                    ),
                    child: Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle ?? track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.ui(11.5, color: p.muted),
                  ),
                ],
              ),
            ),
            trailing ??
                IconBtn(
                  Icons.more_horiz_rounded,
                  tooltip: 'More',
                  color: p.muted,
                  onTap: () =>
                      showTrackActions(context, track, onRemove: onRemove),
                ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet of actions for a song.
Future<void> showTrackActions(
  BuildContext context,
  Track track, {
  VoidCallback? onRemove,
}) {
  final player = context.read<PlayerController>();
  final library = context.read<LibraryController>();
  // Screen context stays valid for snackbars/navigation after the sheet pops.
  final screen = context;

  return showModalBottomSheet<void>(
    context: context,
    builder: (sheet) {
      final p = sheet.palette;
      final liked = library.isLiked(track.id);

      Widget action(IconData icon, String label, VoidCallback onTap) =>
          ListTile(
            leading: Icon(icon, color: p.fg, size: 22),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  Artwork(url: track.imageUrl, size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.ui(
                            15,
                            weight: FontWeight.w600,
                            color: p.fg,
                          ),
                        ),
                        Text(
                          track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.ui(12, color: p.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: p.border),
            action(Icons.playlist_play_rounded, 'Play next', () {
              player.playNext(track);
              showSnack(screen, 'Playing next');
            }),
            action(Icons.queue_music_rounded, 'Add to queue', () {
              player.addToQueue(track);
              showSnack(screen, 'Added to queue');
            }),
            action(
              liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              liked ? 'Remove from Liked Songs' : 'Add to Liked Songs',
              () => library.toggleLike(track),
            ),
            action(
              Icons.playlist_add_rounded,
              'Add to playlist',
              () => showAddToPlaylist(screen, track),
            ),
            if (onRemove != null)
              action(
                Icons.remove_circle_outline_rounded,
                'Remove from this playlist',
                onRemove,
              ),
            if (track.artistId != null)
              action(
                Icons.person_outline_rounded,
                'Go to artist',
                () => screen.openArtist(track.artistId!),
              ),
            if (track.albumId.isNotEmpty)
              action(
                Icons.album_outlined,
                'Go to album',
                () => screen.openAlbum(track.albumId),
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

Future<void> showAddToPlaylist(BuildContext context, Track track) {
  final library = context.read<LibraryController>();
  final screen = context;

  void add(String playlistId, String name) {
    final added = library.addToPlaylist(playlistId, track);
    showSnack(screen, added ? 'Added to $name' : 'Already in $name');
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) {
      final p = sheet.palette;
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheet).height * 0.6,
        ),
        child: SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  'Add to playlist',
                  style: AppText.ui(16, weight: FontWeight.w600, color: p.fg),
                ),
              ),
              ListTile(
                leading: Icon(Icons.add_rounded, color: p.fg),
                title: Text('New playlist', style: AppText.ui(14, color: p.fg)),
                onTap: () async {
                  Navigator.pop(sheet);
                  final created = await showCreatePlaylistDialog(screen);
                  if (created != null) add(created.id, created.name);
                },
              ),
              for (final playlist in library.playlists)
                ListTile(
                  leading: Artwork(
                    url: playlist.tracks.firstOrNull?.imageUrl ?? '',
                    size: 40,
                    icon: Icons.queue_music_rounded,
                  ),
                  title: Text(
                    playlist.name,
                    style: AppText.ui(14, color: p.fg),
                  ),
                  subtitle: Text(
                    '${playlist.tracks.length} songs',
                    style: AppText.ui(12, color: p.muted),
                  ),
                  onTap: () {
                    Navigator.pop(sheet);
                    add(playlist.id, playlist.name);
                  },
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// Asks for a name and creates the playlist. Returns null if cancelled.
Future<UserPlaylist?> showCreatePlaylistDialog(
  BuildContext context, {
  UserPlaylist? renaming,
}) async {
  final library = context.read<LibraryController>();
  final name = await showDialog<String>(
    context: context,
    builder: (_) => _PlaylistNameDialog(initialName: renaming?.name),
  );
  if (name == null) return null;
  if (renaming != null) {
    library.renamePlaylist(renaming.id, name);
    return library.playlist(renaming.id);
  }
  return library.createPlaylist(name);
}

/// Owns its [TextEditingController] so it's disposed only after the dialog's
/// closing animation finishes (disposing it right after `showDialog` returns
/// crashes, because the TextField still rebuilds while fading out).
class _PlaylistNameDialog extends StatefulWidget {
  const _PlaylistNameDialog({this.initialName});

  final String? initialName;

  @override
  State<_PlaylistNameDialog> createState() => _PlaylistNameDialogState();
}

class _PlaylistNameDialogState extends State<_PlaylistNameDialog> {
  late final _controller = TextEditingController(text: widget.initialName);

  bool get _renaming => widget.initialName != null;

  void _submit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) Navigator.pop(context, text);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AlertDialog(
      title: Text(
        _renaming ? 'Rename playlist' : 'New playlist',
        style: AppText.ui(17, weight: FontWeight.w600, color: p.fg),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        style: AppText.ui(14, color: p.fg),
        decoration: const InputDecoration(hintText: 'Playlist name'),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: AppText.ui(14, color: p.muted)),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(
            _renaming ? 'Save' : 'Create',
            style: AppText.ui(14, weight: FontWeight.w600, color: p.fg),
          ),
        ),
      ],
    );
  }
}
