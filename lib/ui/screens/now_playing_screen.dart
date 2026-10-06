import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models.dart';
import '../../state/library_controller.dart';
import '../../state/player_controller.dart';
import '../navigation.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';
import '../widgets/track_tile.dart';
import '../widgets/waveform_seek_bar.dart';

/// Full-screen player (dark): a living mood backdrop, 3D artwork you can
/// swipe like a card to skip, the waveform scrubber, transport controls and
/// a pull-up handle for lyrics. Drag down anywhere to close.
class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen>
    with SingleTickerProviderStateMixin {
  /// Downward drag in pixels for drag-to-dismiss.
  late final _dismiss = AnimationController.unbounded(vsync: this);

  void _onDragUpdate(DragUpdateDetails d) =>
      _dismiss.value = math.max(0, _dismiss.value + d.delta.dy);

  void _onDragEnd(DragEndDetails d) {
    if (_dismiss.value > 140 || (d.primaryVelocity ?? 0) > 700) {
      Navigator.pop(context);
    } else {
      _dismiss.animateTo(
        0,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutBack,
      );
    }
  }

  @override
  void dispose() {
    _dismiss.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final track = player.current;

    return ThemedScreen(
      dark: true,
      child: Builder(
        builder: (context) {
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

          return GestureDetector(
            onVerticalDragUpdate: _onDragUpdate,
            onVerticalDragEnd: _onDragEnd,
            child: AnimatedBuilder(
              animation: _dismiss,
              builder: (context, child) {
                final dy = _dismiss.value;
                final s = 1 - math.min(dy / 2400, 0.12).toDouble();
                return Transform(
                  alignment: Alignment.topCenter,
                  transform: Matrix4.identity()
                    ..translateByDouble(0, dy, 0, 1)
                    ..scaleByDouble(s, s, 1, 1),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(math.min(dy / 4, 32)),
                    clipBehavior: dy == 0 ? Clip.none : Clip.antiAlias,
                    child: child,
                  ),
                );
              },
              child: Scaffold(
                body: Stack(
                  fit: StackFit.expand,
                  children: [
                    MoodBackdrop(
                      imageUrl: track.imageUrl,
                      animate: player.isPlaying,
                    ),
                    SafeArea(
                      child: _PlayerLayout(player: player, track: track),
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

/// Lays the player out to fit any screen: the artwork takes whatever height
/// is left; on very short screens everything scrolls instead.
class _PlayerLayout extends StatelessWidget {
  const _PlayerLayout({required this.player, required this.track});

  final PlayerController player;
  final Track track;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final liked = context.select<LibraryController, bool>(
      (l) => l.isLiked(track.id),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 600;
        final artwork = Padding(
          padding: const EdgeInsets.fromLTRB(28, 12, 28, 0),
          child: _ArtworkStage(player: player, track: track),
        );

        final children = <Widget>[
          // ---- top bar ----
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                IconBtn(
                  Icons.keyboard_arrow_down_rounded,
                  size: 30,
                  tooltip: 'Close',
                  onTap: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'NOW PLAYING',
                        style: AppText.ui(
                          10,
                          weight: FontWeight.w700,
                          color: p.fg.withValues(alpha: 0.7),
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        track.album.isEmpty ? track.artist : track.album,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.ui(
                          12,
                          weight: FontWeight.w600,
                          color: p.fg,
                        ),
                      ),
                    ],
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
          if (compact)
            SizedBox(
              height: math.min(constraints.maxWidth - 56, 300),
              child: artwork,
            )
          else
            Expanded(child: artwork),

          // ---- title + like ----
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 28, 18, 0),
            child: Row(
              children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: Motion.slow,
                    switchInCurve: Motion.decelerate,
                    transitionBuilder: (child, a) => FadeTransition(
                      opacity: a,
                      child: SlideTransition(
                        position: Tween(
                          begin: const Offset(0.15, 0),
                          end: Offset.zero,
                        ).animate(a),
                        child: child,
                      ),
                    ),
                    layoutBuilder: (current, previous) => Stack(
                      alignment: Alignment.centerLeft,
                      children: [...previous, ?current],
                    ),
                    child: GestureDetector(
                      key: ValueKey(track.id),
                      onTap: track.artistId == null
                          ? null
                          : () => context.openArtist(track.artistId!),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.ui(
                              23,
                              weight: FontWeight.w800,
                              color: p.fg,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.ui(
                              14,
                              weight: FontWeight.w500,
                              color: p.fg.withValues(alpha: 0.65),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                HeartButton(
                  liked: liked,
                  size: 28,
                  onTap: () =>
                      context.read<LibraryController>().toggleLike(track),
                ),
              ],
            ),
          ),

          // ---- scrubber ----
          // Own layer: position ticks repaint only the scrubber.
          RepaintBoundary(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 18, 28, 0),
              child: StreamBuilder<Duration>(
                stream: player.positionStream,
                builder: (context, snap) => WaveformSeekBar(
                  seed: track.id,
                  position: snap.data ?? player.position,
                  duration: player.duration,
                  onSeek: player.seek,
                  playing: player.isPlaying,
                ),
              ),
            ),
          ),

          // ---- transport ----
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _ToggleIcon(
                  icon: Icons.shuffle_rounded,
                  tooltip: 'Shuffle',
                  active: player.shuffleEnabled,
                  onTap: player.toggleShuffle,
                ),
                _SkipButton(
                  icon: Icons.skip_previous_rounded,
                  tooltip: 'Previous',
                  onTap: player.previous,
                ),
                _BigPlayButton(player: player),
                _SkipButton(
                  icon: Icons.skip_next_rounded,
                  tooltip: 'Next',
                  onTap: player.next,
                ),
                _ToggleIcon(
                  icon: player.loopMode == LoopMode.one
                      ? Icons.repeat_one_rounded
                      : Icons.repeat_rounded,
                  tooltip: 'Repeat',
                  active: player.loopMode != LoopMode.off,
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
        ];

        final column = Column(children: children);
        return compact
            ? SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: column,
              )
            : column;
      },
    );
  }
}

/// The cover in 3D: floats gently while playing, shrinks back when paused,
/// tilts toward your finger, and can be flung sideways like a card to skip.
/// When the song changes it slides in from the side it came from.
class _ArtworkStage extends StatefulWidget {
  const _ArtworkStage({required this.player, required this.track});

  final PlayerController player;
  final Track track;

  @override
  State<_ArtworkStage> createState() => _ArtworkStageState();
}

class _ArtworkStageState extends State<_ArtworkStage>
    with TickerProviderStateMixin {
  /// Horizontal card position as a fraction of the width (0 = centered).
  late final _swipe = AnimationController.unbounded(vsync: this);

  /// Idle float loop while playing.
  late final _float = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );

  /// How strongly the cover tilts toward [_touch] (0..1).
  late final _press = AnimationController(vsync: this);
  Offset _touch = Offset.zero;

  late String _shownId = widget.track.id;
  int? _lastIndex;

  /// Set while waiting for the player to change song after a fling:
  /// +1 = next (new cover enters from the right), -1 = previous.
  int? _pendingDir;
  Timer? _pendingTimeout;

  late final _merged = Listenable.merge([_swipe, _float, _press]);

  @override
  void initState() {
    super.initState();
    _lastIndex = widget.player.currentIndex;
    widget.player.addListener(_onPlayer);
  }

  void _onPlayer() {
    final player = widget.player;
    final current = player.current;
    if (current == null || current.id == _shownId) {
      _syncFloat();
      return;
    }
    final index = player.currentIndex ?? 0;
    final dir = _pendingDir ?? (index >= (_lastIndex ?? 0) ? 1 : -1);
    _pendingDir = null;
    _pendingTimeout?.cancel();
    _shownId = current.id;
    _lastIndex = index;
    // Start the new cover off to the side, then glide it in.
    _swipe.value = dir * 1.1;
    _swipe.animateTo(
      0,
      duration: const Duration(milliseconds: 720),
      curve: Motion.decelerate,
    );
    _syncFloat();
  }

  void _syncFloat() {
    if (!mounted) return;
    final run = widget.player.isPlaying && !Motion.reduced(context);
    if (run && !_float.isAnimating) _float.repeat();
    if (!run && _float.isAnimating) _float.stop();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncFloat();
  }

  void _onDragEnd(DragEndDetails d, double width) {
    final x = _swipe.value;
    final v = (d.primaryVelocity ?? 0) / width;
    final dir = (x < -0.28 || v < -1.2)
        ? 1
        : (x > 0.28 || v > 1.2)
        ? -1
        : 0;
    if (dir == 0) {
      _swipe.animateTo(
        0,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutBack,
      );
      return;
    }
    // Fling the card out, then change song; it comes back in via _onPlayer.
    _pendingDir = dir;
    _swipe
        .animateTo(
          -dir * 1.1,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeIn,
        )
        .whenCompleteOrCancel(() {
          if (!mounted) return;
          dir == 1 ? widget.player.next() : widget.player.previous();
          // No song change (end of queue / restart): bounce back.
          _pendingTimeout?.cancel();
          _pendingTimeout = Timer(const Duration(milliseconds: 700), () {
            if (!mounted || _pendingDir == null) return;
            _pendingDir = null;
            _swipe.value = dir * 1.1;
            _swipe.animateTo(
              0,
              duration: const Duration(milliseconds: 620),
              curve: Motion.decelerate,
            );
          });
        });
  }

  void _setTouch(Offset local, Size size) {
    _touch = Offset(
      (local.dx / size.width * 2 - 1).clamp(-1.0, 1.0),
      (local.dy / size.height * 2 - 1).clamp(-1.0, 1.0),
    );
  }

  @override
  void dispose() {
    widget.player.removeListener(_onPlayer);
    _pendingTimeout?.cancel();
    _swipe.dispose();
    _float.dispose();
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final playing = widget.player.isPlaying;

    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.max(
          0.0,
          math.min(constraints.maxWidth, constraints.maxHeight),
        );
        final stageSize = Size.square(side);
        return Center(
          child: Listener(
            onPointerDown: (e) {
              _setTouch(e.localPosition, stageSize);
              _press.animateTo(1, duration: Motion.fast, curve: Curves.easeOut);
            },
            onPointerMove: (e) => _setTouch(e.localPosition, stageSize),
            onPointerUp: (_) => _press.animateTo(
              0,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutBack,
            ),
            onPointerCancel: (_) =>
                _press.animateTo(0, duration: Motion.medium),
            child: GestureDetector(
              onHorizontalDragStart: (_) {
                _pendingDir = null;
                _swipe.stop();
              },
              onHorizontalDragUpdate: (d) =>
                  _swipe.value += d.delta.dx / math.max(side, 1),
              onHorizontalDragEnd: (d) => _onDragEnd(d, math.max(side, 1)),
              child: AnimatedScale(
                // Paused covers sit back a little, like Apple Music.
                scale: playing ? 1 : 0.86,
                duration: const Duration(milliseconds: 700),
                curve: playing ? Curves.easeOutBack : Curves.easeOutCubic,
                child: AnimatedBuilder(
                  animation: _merged,
                  builder: (context, child) => _transformed(child!, side),
                  // Cached layer: the float/tilt only moves it, so the
                  // cover and its big glow shadow aren't redrawn each frame.
                  child: RepaintBoundary(
                    child: _Cover(
                      track: widget.track,
                      side: side,
                      glow: p.accent,
                      playing: playing,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _transformed(Widget child, double side) {
    final x = _swipe.value;
    final ax = x.abs().clamp(0.0, 1.2);
    final f = _float.value * 2 * math.pi;
    final press = _press.value;

    final tiltX = math.sin(f) * 0.05 + _touch.dy * 0.22 * press;
    final tiltY = math.cos(f) * 0.07 - _touch.dx * 0.22 * press - x * 0.9;
    final s = 1 - ax * 0.2 - press * 0.03;

    return Opacity(
      opacity: (1.2 - ax).clamp(0.0, 1.0),
      child: Transform(
        alignment: Alignment.center,
        transform: Motion.perspective()
          ..translateByDouble(x * side * 0.85, math.sin(f * 2) * 4, 0, 1)
          ..rotateX(tiltX)
          ..rotateY(tiltY)
          ..scaleByDouble(s, s, 1, 1),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            child,
            // Specular sheen that slides across as the cover turns.
            Positioned.fill(
              child: IgnorePointer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(-1.5 + tiltY * 4, -1 + tiltX * 3),
                        end: Alignment(1.5 + tiltY * 4, 1 + tiltX * 3),
                        colors: [
                          Colors.white.withValues(alpha: 0),
                          Colors.white.withValues(alpha: 0.14),
                          Colors.white.withValues(alpha: 0),
                        ],
                        stops: const [0.3, 0.5, 0.7],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({
    required this.track,
    required this.side,
    required this.glow,
    required this.playing,
  });

  final Track track;
  final double side;
  final Color glow;
  final bool playing;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOutCubic,
      width: side,
      height: side,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: glow.withValues(alpha: playing ? 0.45 : 0.2),
            blurRadius: playing ? 60 : 30,
            spreadRadius: -10,
            offset: const Offset(0, 24),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Hero(
        tag: 'artwork',
        child: Artwork(url: track.imageUrl, radius: 14),
      ),
    );
  }
}

/// Shuffle / repeat: lights up in the accent with a dot when active.
class _ToggleIcon extends StatelessWidget {
  const _ToggleIcon({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: Motion.medium,
          transitionBuilder: (child, a) =>
              ScaleTransition(scale: a, child: child),
          child: IconBtn(
            icon,
            key: ValueKey((icon, active)),
            tooltip: tooltip,
            color: active ? p.accent : p.fg.withValues(alpha: 0.8),
            onTap: onTap,
          ),
        ),
        AnimatedContainer(
          duration: Motion.medium,
          curve: Curves.easeOutBack,
          width: active ? 4 : 0,
          height: active ? 4 : 0,
          decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle),
        ),
      ],
    );
  }
}

/// Previous / next: springy press and a nudge in its direction.
class _SkipButton extends StatelessWidget {
  const _SkipButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: tooltip,
    child: Pressable(
      onTap: onTap,
      scale: 0.8,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 38, color: context.palette.fg),
      ),
    ),
  );
}

class _BigPlayButton extends StatelessWidget {
  const _BigPlayButton({required this.player});

  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Pressable(
      onTap: player.togglePlay,
      scale: 0.88,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeInOutCubic,
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [p.accent, Color.lerp(p.accent, p.glow, 0.7)!],
          ),
          boxShadow: [
            BoxShadow(
              color: p.accent.withValues(alpha: player.isPlaying ? 0.55 : 0.3),
              blurRadius: player.isPlaying ? 34 : 20,
              spreadRadius: -4,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: player.isBuffering
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.ink,
                ),
              )
            : Center(
                child: PlayPauseIcon(
                  playing: player.isPlaying,
                  size: 36,
                  color: AppColors.ink,
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
      child: Pressable(
        onTap: onTap,
        tilt: 0,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: p.accent),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppText.ui(
                  11,
                  weight: FontWeight.w700,
                  color: p.fg,
                  letterSpacing: 1.6,
                ),
              ),
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
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            item('LYRICS', Icons.lyrics_outlined, onLyrics),
            Container(
              width: 1,
              height: 22,
              color: Colors.white.withValues(alpha: 0.12),
            ),
            item('QUEUE', Icons.queue_music_rounded, onQueue),
          ],
        ),
      ),
    );
  }
}
