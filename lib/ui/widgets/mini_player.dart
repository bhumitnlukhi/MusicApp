import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../state/accent_controller.dart';
import '../../state/library_controller.dart';
import '../../state/player_controller.dart';
import '../navigation.dart';
import 'common.dart';

/// Compact "now playing" bar shown above the bottom nav and on detail
/// screens. Always ink-colored so it reads on both light and dark screens.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final track = player.current;
    if (track == null) return const SizedBox.shrink();
    final liked = context.select<LibraryController, bool>(
      (l) => l.isLiked(track.id),
    );

    // Always ink so it reads on light and dark screens, tinted by the song.
    return Theme(
      data: AppTheme.of(
        dark: true,
        colors: context.select<AccentController, SongColors>((a) => a.colors),
      ),
      child: Builder(
        builder: (context) {
          final p = context.palette;
          return Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
            child: GestureDetector(
              onTap: context.openNowPlaying,
              onVerticalDragEnd: (d) {
                if ((d.primaryVelocity ?? 0) < -200) context.openNowPlaying();
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Color.lerp(p.surface, p.accentDeep, 0.9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: p.accent.withValues(alpha: 0.18)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
                      child: Row(
                        children: [
                          Hero(
                            tag: 'artwork',
                            child: Artwork(
                              url: track.imageUrl,
                              size: 40,
                              radius: 3,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  track.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.ui(
                                    13,
                                    weight: FontWeight.w600,
                                    color: p.fg,
                                  ),
                                ),
                                Text(
                                  track.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.ui(11, color: p.muted),
                                ),
                              ],
                            ),
                          ),
                          IconBtn(
                            liked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: liked ? p.accent : p.fg,
                            tooltip: liked ? 'Unlike' : 'Like',
                            onTap: () => context
                                .read<LibraryController>()
                                .toggleLike(track),
                          ),
                          player.isBuffering
                              ? const SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: Padding(
                                    padding: EdgeInsets.all(11),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : IconBtn(
                                  player.isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  size: 28,
                                  tooltip: player.isPlaying ? 'Pause' : 'Play',
                                  onTap: player.togglePlay,
                                ),
                        ],
                      ),
                    ),
                    StreamBuilder<Duration>(
                      stream: player.positionStream,
                      builder: (context, snap) {
                        final total = player.duration.inMilliseconds;
                        final pos = snap.data?.inMilliseconds ?? 0;
                        return LinearProgressIndicator(
                          value: total == 0 ? 0 : (pos / total).clamp(0.0, 1.0),
                          minHeight: 2,
                          color: p.accent,
                          backgroundColor: p.border,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
