import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../state/library_controller.dart';
import '../../state/player_controller.dart';
import '../navigation.dart';
import '../widgets/common.dart';
import '../widgets/track_tile.dart';
import '../widgets/waveform_seek_bar.dart';

/// Full-screen player (dark): artwork, waveform scrubber, transport controls
/// and a pull-up handle for lyrics.
class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final track = player.current;

    return ThemedScreen(
      dark: true,
      child: Builder(
        builder: (context) {
          final p = context.palette;
          if (track == null) {
            // Queue was cleared while this screen was open.
            return Scaffold(
              body: SafeArea(
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconBtn(
                        Icons.keyboard_arrow_down_rounded,
                        size: 28,
                        tooltip: 'Close',
                        onTap: () => Navigator.pop(context),
                      ),
                    ),
                    const Expanded(
                      child: Center(
                        child: MessageView(
                          icon: Icons.music_off_rounded,
                          title: 'Nothing playing',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final liked = context.select<LibraryController, bool>(
            (l) => l.isLiked(track.id),
          );

          return Scaffold(
            body: GestureDetector(
              // Swipe down to close.
              onVerticalDragEnd: (d) {
                if ((d.primaryVelocity ?? 0) > 300) Navigator.pop(context);
              },
              // Soft glow in the song's accent color behind the artwork.
              child: DecoratedBox(
                decoration: songBackdrop(p),
                child: SafeArea(
                  child: Column(
                    children: [
                      // ---- top bar ----
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            IconBtn(
                              Icons.keyboard_arrow_down_rounded,
                              size: 28,
                              tooltip: 'Close',
                              onTap: () => Navigator.pop(context),
                            ),
                            Expanded(
                              child: Text(
                                'NOW PLAYING',
                                textAlign: TextAlign.center,
                                style: AppText.ui(
                                  11,
                                  weight: FontWeight.w600,
                                  color: p.fg,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            IconBtn(
                              Icons.more_vert_rounded,
                              tooltip: 'More',
                              onTap: () => showTrackActions(context, track),
                            ),
                          ],
                        ),
                      ),

                      // ---- artwork ----
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                          child: Center(
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 600),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: p.accent.withValues(alpha: 0.35),
                                      blurRadius: 48,
                                      spreadRadius: -8,
                                      offset: const Offset(0, 16),
                                    ),
                                  ],
                                ),
                                child: Hero(
                                  tag: 'artwork',
                                  child: Artwork(
                                    url: track.imageUrl,
                                    radius: 4,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // ---- title + like ----
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 16, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: track.artistId == null
                                    ? null
                                    : () => context.openArtist(track.artistId!),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      track.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppText.ui(
                                        22,
                                        weight: FontWeight.w700,
                                        color: p.fg,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      track.artist,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppText.ui(13, color: p.muted),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            IconBtn(
                              liked
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 26,
                              color: liked ? p.accent : p.fg,
                              tooltip: liked ? 'Unlike' : 'Like',
                              onTap: () => context
                                  .read<LibraryController>()
                                  .toggleLike(track),
                            ),
                          ],
                        ),
                      ),

                      // ---- scrubber ----
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                        child: StreamBuilder<Duration>(
                          stream: player.positionStream,
                          builder: (context, snap) => WaveformSeekBar(
                            seed: track.id,
                            position: snap.data ?? player.position,
                            duration: player.duration,
                            onSeek: player.seek,
                          ),
                        ),
                      ),

                      // ---- transport ----
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconBtn(
                              Icons.shuffle_rounded,
                              tooltip: 'Shuffle',
                              color: player.shuffleEnabled ? p.accent : p.fg,
                              onTap: player.toggleShuffle,
                            ),
                            IconBtn(
                              Icons.skip_previous_rounded,
                              size: 32,
                              tooltip: 'Previous',
                              onTap: player.previous,
                            ),
                            _BigPlayButton(player: player),
                            IconBtn(
                              Icons.skip_next_rounded,
                              size: 32,
                              tooltip: 'Next',
                              onTap: player.next,
                            ),
                            IconBtn(
                              player.loopMode == LoopMode.one
                                  ? Icons.repeat_one_rounded
                                  : Icons.repeat_rounded,
                              tooltip: 'Repeat',
                              color: player.loopMode == LoopMode.off
                                  ? p.fg
                                  : p.accent,
                              onTap: player.cycleRepeat,
                            ),
                          ],
                        ),
                      ),

                      // ---- lyrics / queue handle ----
                      _BottomHandle(
                        onLyrics: context.openLyrics,
                        onQueue: context.openQueue,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BigPlayButton extends StatelessWidget {
  const _BigPlayButton({required this.player});

  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      label: player.isPlaying ? 'Pause' : 'Play',
      child: GestureDetector(
        onTap: player.togglePlay,
        child: Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: p.fg, width: 1.5),
          ),
          child: player.isBuffering
              ? const Padding(
                  padding: EdgeInsets.all(22),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  player.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 34,
                  color: p.fg,
                ),
        ),
      ),
    );
  }
}

class _BottomHandle extends StatelessWidget {
  const _BottomHandle({required this.onLyrics, required this.onQueue});

  final VoidCallback onLyrics;
  final VoidCallback onQueue;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget item(String label, IconData icon, VoidCallback onTap) => Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Text(
                label,
                style: AppText.ui(
                  11,
                  weight: FontWeight.w600,
                  color: p.fg,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Icon(icon, size: 18, color: p.muted),
            ],
          ),
        ),
      ),
    );

    return GestureDetector(
      onVerticalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) < -200) onLyrics();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        ),
        child: Row(
          children: [
            item('LYRICS', Icons.keyboard_arrow_up_rounded, onLyrics),
            Container(width: 1, height: 28, color: p.border),
            item('QUEUE', Icons.keyboard_arrow_up_rounded, onQueue),
          ],
        ),
      ),
    );
  }
}
