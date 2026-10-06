import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/lyrics_repository.dart';
import '../../data/models.dart';
import '../../state/library_controller.dart';
import '../../state/player_controller.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';

/// Lyrics (light, monospace). Synced lyrics highlight and follow the current
/// line; tap a line to jump there.
class LyricsScreen extends StatelessWidget {
  const LyricsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final track = player.current;

    return ThemedScreen(
      dark: false,
      child: Builder(
        builder: (context) {
          final p = context.palette;
          return Scaffold(
            body: SafeArea(
              child: track == null
                  ? const Center(
                      child: MessageView(
                        icon: Icons.lyrics_outlined,
                        title: 'Nothing playing',
                      ),
                    )
                  : Column(
                      children: [
                        _Header(track: track),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: p.border),
                                bottom: BorderSide(color: p.border),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'LYRICS',
                                    style: AppText.ui(
                                      11,
                                      weight: FontWeight.w700,
                                      color: p.fg,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.notes_rounded,
                                  size: 20,
                                  color: p.fg,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: AsyncView<Lyrics?>(
                            key: ValueKey(track.id),
                            load: () =>
                                context.read<LyricsRepository>().fetch(track),
                            builder: (context, lyrics) => lyrics == null
                                ? const Center(
                                    child: MessageView(
                                      icon: Icons.lyrics_outlined,
                                      title: 'No lyrics for this song',
                                      subtitle:
                                          'Lyrics come from LRCLIB and '
                                          "aren't available for every track.",
                                    ),
                                  )
                                : _LyricsBody(lyrics: lyrics),
                          ),
                        ),
                        const _BottomControls(),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final liked = context.select<LibraryController, bool>(
      (l) => l.isLiked(track.id),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 16),
      child: Row(
        children: [
          Artwork(url: track.imageUrl, size: 44, radius: 3),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.ui(14, weight: FontWeight.w600, color: p.fg),
                ),
                Text(
                  track.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.ui(11.5, color: p.muted),
                ),
              ],
            ),
          ),
          IconBtn(
            liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            tooltip: liked ? 'Unlike' : 'Like',
            onTap: () => context.read<LibraryController>().toggleLike(track),
          ),
          IconBtn(
            Icons.keyboard_arrow_down_rounded,
            size: 28,
            tooltip: 'Close',
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class _LyricsBody extends StatefulWidget {
  const _LyricsBody({required this.lyrics});

  final Lyrics lyrics;

  @override
  State<_LyricsBody> createState() => _LyricsBodyState();
}

class _LyricsBodyState extends State<_LyricsBody> {
  late final List<GlobalKey> _keys = List.generate(
    widget.lyrics.lines.length,
    (_) => GlobalKey(),
  );
  int _active = -1;

  /// Current line index, emitted only when it changes — so the lyrics list
  /// rebuilds once per line instead of on every position tick.
  late final Stream<int> _activeStream = context
      .read<PlayerController>()
      .positionStream
      .map(_activeLine)
      .distinct();

  int _activeLine(Duration position) {
    final lines = widget.lyrics.lines;
    var active = -1;
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].time! <= position) {
        active = i;
      } else {
        break;
      }
    }
    return active;
  }

  void _follow(int index) {
    if (index == _active) return;
    _active = index;
    if (index < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keys[index].currentContext;
      if (ctx != null && mounted) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.35,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final player = context.read<PlayerController>();
    final lines = widget.lyrics.lines;

    if (!widget.lyrics.isSynced) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          for (final line in lines)
            Text(line.text, style: AppText.mono(13.5, color: p.fg)),
        ],
      );
    }

    return StreamBuilder<int>(
      stream: _activeStream,
      initialData: _activeLine(player.position),
      builder: (context, snap) {
        final active = snap.data ?? -1;
        _follow(active);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < lines.length; i++)
                GestureDetector(
                  key: _keys[i],
                  onTap: () => player.seek(lines[i].time!),
                  behavior: HitTestBehavior.opaque,
                  // The current line grows and gets an accent bar; past
                  // lines fade more than upcoming ones.
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    padding: EdgeInsets.only(left: i == active ? 12 : 0),
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: i == active
                              ? AppColors.ink
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    child: AnimatedScale(
                      scale: i == active ? 1.06 : 1,
                      alignment: Alignment.centerLeft,
                      duration: const Duration(milliseconds: 420),
                      curve: Curves.easeOutBack,
                      child: AnimatedDefaultTextStyle(
                        duration: Motion.medium,
                        style: AppText.mono(
                          13.5,
                          color: i == active
                              ? p.fg
                              : p.muted.withValues(
                                  alpha: i < active ? 0.45 : 0.75,
                                ),
                          weight: i == active
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                        // Empty LRC lines are instrumental breaks.
                        child: Text(
                          lines[i].text.isEmpty ? '♪' : lines[i].text,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _BottomControls extends StatelessWidget {
  const _BottomControls();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final player = context.watch<PlayerController>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        children: [
          // Own layer: the slider's ticks don't repaint the lyrics.
          RepaintBoundary(
            child: StreamBuilder<Duration>(
              stream: player.positionStream,
              builder: (context, snap) {
                final pos = snap.data ?? player.position;
                final total = player.duration;
                final max = total.inMilliseconds.toDouble();
                return Column(
                  children: [
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 3,
                        activeTrackColor: p.accent,
                        inactiveTrackColor: p.border,
                        thumbColor: p.accent,
                        overlayShape: SliderComponentShape.noOverlay,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 5,
                        ),
                      ),
                      child: Slider(
                        value: max == 0
                            ? 0
                            : pos.inMilliseconds.clamp(0, max).toDouble(),
                        max: max == 0 ? 1 : max,
                        onChanged: max == 0
                            ? null
                            : (v) => player.seek(
                                Duration(milliseconds: v.round()),
                              ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          formatDuration(pos),
                          style: AppText.ui(11, color: p.muted),
                        ),
                        const Spacer(),
                        Text(
                          formatDuration(total),
                          style: AppText.ui(11, color: p.muted),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          RoundPlayButton(
            size: 56,
            playing: player.isPlaying,
            onTap: player.togglePlay,
          ),
        ],
      ),
    );
  }
}
