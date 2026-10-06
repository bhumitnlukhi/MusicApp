import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models.dart';
import '../../state/accent_controller.dart';
import '../../state/library_controller.dart';
import '../../state/player_controller.dart';
import '../navigation.dart';
import 'common.dart';
import 'motion.dart';

/// Compact "now playing" bar shown above the bottom nav and on detail
/// screens. Always ink-colored so it reads on both light and dark screens.
/// Tap or swipe up to open the player, swipe sideways to skip.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final track = context.select<PlayerController, Track?>((c) => c.current);

    // Grows in from nothing when the first song starts.
    return AnimatedSize(
      duration: Motion.slow,
      curve: Motion.decelerate,
      alignment: Alignment.bottomCenter,
      child: track == null
          ? const SizedBox(width: double.infinity)
          : Theme(
              // Always ink so it reads on light and dark screens, tinted by
              // the song.
              data: AppTheme.of(
                dark: true,
                colors: context.select<AccentController, SongColors>(
                  (a) => a.colors,
                ),
              ),
              child: _MiniPlayerBar(track: track),
            ),
    );
  }
}

class _MiniPlayerBar extends StatefulWidget {
  const _MiniPlayerBar({required this.track});

  final Track track;

  @override
  State<_MiniPlayerBar> createState() => _MiniPlayerBarState();
}

class _MiniPlayerBarState extends State<_MiniPlayerBar>
    with SingleTickerProviderStateMixin {
  /// Horizontal drag offset in pixels (springs back to 0).
  late final _drag = AnimationController.unbounded(vsync: this);

  void _onDragEnd(DragEndDetails d) {
    final player = context.read<PlayerController>();
    final v = d.primaryVelocity ?? 0;
    final dx = _drag.value;
    if (dx < -70 || v < -600) {
      player.next();
    } else if (dx > 70 || v > 600) {
      player.previous();
    }
    _drag.animateTo(
      0,
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutBack,
    );
  }

  @override
  void dispose() {
    _drag.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final player = context.watch<PlayerController>();
    final track = widget.track;
    final liked = context.select<LibraryController, bool>(
      (l) => l.isLiked(track.id),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
      child: GestureDetector(
        onTap: context.openNowPlaying,
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) < -200) context.openNowPlaying();
        },
        onHorizontalDragUpdate: (d) => _drag.value += d.delta.dx,
        onHorizontalDragEnd: _onDragEnd,
        child: AnimatedBuilder(
          animation: _drag,
          builder: (context, child) {
            final dx = _drag.value;
            return Transform(
              alignment: Alignment.center,
              transform: Motion.perspective()
                ..translateByDouble(dx * 0.6, 0, 0, 1)
                ..rotateY(-dx / 900),
              child: child,
            );
          },
          child: RepaintBoundary(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeInOutCubic,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color.lerp(p.accentDeep, p.accent, 0.16)!,
                    Color.lerp(p.surface, p.accentDeep, 0.9)!,
                    Color.lerp(p.accentDeep, p.glow, 0.1)!,
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: p.accent.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(
                    color: p.accent.withValues(alpha: 0.18),
                    blurRadius: 22,
                    spreadRadius: -6,
                    offset: const Offset(0, 8),
                  ),
                ],
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
                          child: _FlipSwitcher(
                            id: track.id,
                            child: Artwork(
                              url: track.imageUrl,
                              size: 42,
                              radius: 8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: Motion.medium,
                            transitionBuilder: (child, a) => FadeTransition(
                              opacity: a,
                              child: SlideTransition(
                                position: Tween(
                                  begin: const Offset(0, 0.4),
                                  end: Offset.zero,
                                ).animate(a),
                                child: child,
                              ),
                            ),
                            layoutBuilder: (current, previous) => Stack(
                              alignment: Alignment.centerLeft,
                              children: [...previous, ?current],
                            ),
                            child: Column(
                              key: ValueKey(track.id),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    if (player.isPlaying) ...[
                                      EqualizerBars(
                                        playing: true,
                                        size: 11,
                                        color: p.accent,
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    Expanded(
                                      child: Text(
                                        track.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppText.ui(
                                          13,
                                          weight: FontWeight.w600,
                                          color: p.fg,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  track.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.ui(11, color: p.muted),
                                ),
                              ],
                            ),
                          ),
                        ),
                        HeartButton(
                          liked: liked,
                          size: 22,
                          onTap: () => context
                              .read<LibraryController>()
                              .toggleLike(track),
                        ),
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: player.isBuffering
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Pressable(
                                  onTap: player.togglePlay,
                                  scale: 0.8,
                                  tilt: 0,
                                  child: Center(
                                    child: PlayPauseIcon(
                                      playing: player.isPlaying,
                                      size: 28,
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                  // Position ticks repaint just this line, not the screen.
                  RepaintBoundary(child: _ProgressLine(player: player)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Thin glowing progress line along the bottom of the mini player.
class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.player});

  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      height: 2.5,
      child: StreamBuilder<Duration>(
        stream: player.positionStream,
        builder: (context, snap) {
          final total = player.duration.inMilliseconds;
          final pos = snap.data?.inMilliseconds ?? 0;
          final f = total == 0 ? 0.0 : (pos / total).clamp(0.0, 1.0);
          return Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: p.border.withValues(alpha: 0.6)),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: f,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [p.accent, p.glow]),
                    boxShadow: [
                      BoxShadow(
                        color: p.accent.withValues(alpha: 0.7),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Flips its child around the Y axis like a card whenever [id] changes.
class _FlipSwitcher extends StatelessWidget {
  const _FlipSwitcher({required this.id, required this.child});

  final String id;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: Motion.slow,
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeInCubic,
    transitionBuilder: (child, a) => AnimatedBuilder(
      animation: a,
      child: child,
      builder: (context, child) {
        final incoming = child?.key == ValueKey(id);
        // Only the second half of each side is visible: the old cover turns
        // away, then the new one turns in.
        final turn = (1 - a.value) * (incoming ? -1 : 1) * 3.1416;
        return Opacity(
          opacity: a.value < 0.5 ? 0 : 1,
          child: Transform(
            alignment: Alignment.center,
            transform: Motion.perspective()..rotateY(turn),
            child: child,
          ),
        );
      },
    ),
    child: KeyedSubtree(key: ValueKey(id), child: child),
  );
}
