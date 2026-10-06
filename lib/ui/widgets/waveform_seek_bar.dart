import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'common.dart';

/// The waveform scrubber from the Now Playing design. The bar heights are
/// decorative (seeded from the track id so each song looks different) and
/// dance around the playhead while the song plays; drag or tap to seek.
class WaveformSeekBar extends StatefulWidget {
  const WaveformSeekBar({
    super.key,
    required this.seed,
    required this.position,
    required this.duration,
    required this.onSeek,
    this.playing = false,
  });

  final String seed;
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  final bool playing;

  @override
  State<WaveformSeekBar> createState() => _WaveformSeekBarState();
}

class _WaveformSeekBarState extends State<WaveformSeekBar>
    with TickerProviderStateMixin {
  static const _barCount = 56;
  late List<double> _bars = _makeBars(widget.seed);

  /// Drives the dancing (loops forever while playing).
  late final _wave = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  /// How much the bars dance: eases in on play, out on pause.
  late final _amp = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
    value: widget.playing ? 1 : 0,
  );

  /// Grows the playhead knob while dragging.
  late final _grab = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );

  late final _repaint = Listenable.merge([_wave, _amp, _grab]);

  /// While dragging, show the drag position instead of the player's.
  double? _dragFraction;

  @override
  void initState() {
    super.initState();
    _syncPlaying();
  }

  @override
  void didUpdateWidget(WaveformSeekBar old) {
    super.didUpdateWidget(old);
    if (old.seed != widget.seed) _bars = _makeBars(widget.seed);
    if (old.playing != widget.playing) _syncPlaying();
  }

  void _syncPlaying() {
    if (widget.playing) {
      if (!_wave.isAnimating) _wave.repeat();
      _amp.animateTo(1, curve: Curves.easeOut);
    } else {
      _amp.animateTo(0, curve: Curves.easeOut).whenCompleteOrCancel(() {
        if (mounted && !widget.playing) _wave.stop();
      });
    }
  }

  @override
  void dispose() {
    _wave.dispose();
    _amp.dispose();
    _grab.dispose();
    super.dispose();
  }

  static List<double> _makeBars(String seed) {
    final rng = Random(seed.hashCode);
    // Smoothed noise with a louder middle, so it looks like a real song.
    var prev = 0.5;
    return List.generate(_barCount, (i) {
      final envelope = 0.55 + 0.45 * sin(pi * i / _barCount);
      prev = (prev * 0.45) + rng.nextDouble() * 0.55;
      return (0.18 + prev * 0.82) * envelope;
    });
  }

  double get _fraction {
    if (_dragFraction != null) return _dragFraction!;
    final total = widget.duration.inMilliseconds;
    if (total == 0) return 0;
    return (widget.position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  void _updateDrag(Offset local, double width) {
    if (_dragFraction == null) _grab.forward();
    setState(() => _dragFraction = (local.dx / width).clamp(0.0, 1.0));
  }

  void _commit() {
    final f = _dragFraction;
    _grab.reverse();
    if (f == null) return;
    widget.onSeek(widget.duration * f);
    setState(() => _dragFraction = null);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final shownPosition = widget.duration * _fraction;
    final timeStyle = AppText.ui(
      11,
      color: p.muted,
      weight: FontWeight.w500,
    ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return Semantics(
              slider: true,
              label: 'Seek',
              value: formatDuration(shownPosition),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (d) =>
                    _updateDrag(d.localPosition, width),
                onHorizontalDragUpdate: (d) =>
                    _updateDrag(d.localPosition, width),
                onHorizontalDragEnd: (_) => _commit(),
                onHorizontalDragCancel: _commit,
                onTapDown: (d) => _updateDrag(d.localPosition, width),
                onTapUp: (_) => _commit(),
                onTapCancel: _commit,
                child: RepaintBoundary(
                  child: SizedBox(
                    height: 52,
                    width: width,
                    child: CustomPaint(
                      painter: _WaveformPainter(
                        repaint: _repaint,
                        wave: _wave,
                        amp: _amp,
                        grab: _grab,
                        bars: _bars,
                        fraction: _fraction,
                        played: p.accent,
                        playedEnd: p.glow,
                        unplayed: p.fg.withValues(alpha: 0.16),
                        energy: p.energy,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(formatDuration(shownPosition), style: timeStyle),
            const Spacer(),
            Text(formatDuration(widget.duration), style: timeStyle),
          ],
        ),
      ],
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required Listenable repaint,
    required this.wave,
    required this.amp,
    required this.grab,
    required this.bars,
    required this.fraction,
    required this.played,
    required this.playedEnd,
    required this.unplayed,
    required this.energy,
  }) : super(repaint: repaint);

  final Animation<double> wave;
  final Animation<double> amp;
  final Animation<double> grab;
  final List<double> bars;
  final double fraction;
  final Color played;
  final Color playedEnd;
  final Color unplayed;
  final double energy;

  @override
  void paint(Canvas canvas, Size size) {
    final slot = size.width / bars.length;
    final barWidth = max(2.0, slot * 0.5);
    final mid = size.height / 2;
    final head = fraction * bars.length;
    // Energetic songs bounce faster (2–4 cycles per loop of [wave]).
    final t = wave.value * 2 * pi * (2 + (energy * 2).round());
    final a = amp.value;

    final playedPath = Path();
    final unplayedPath = Path();
    for (var i = 0; i < bars.length; i++) {
      final x = slot * i + slot / 2;
      // Bars near the playhead move the most.
      final near = exp(-pow(i - head, 2) / 60);
      final dance = a * (0.12 + 0.45 * near) * sin(t + i * 0.7);
      final h = (bars[i] * (1 + dance)).clamp(0.08, 1.0) * size.height * 0.85;
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, mid), width: barWidth, height: h),
        Radius.circular(barWidth / 2),
      );
      ((x / size.width) <= fraction ? playedPath : unplayedPath).addRRect(rect);
    }

    final shader = LinearGradient(
      colors: [played, playedEnd],
    ).createShader(Offset.zero & size);

    canvas.drawPath(unplayedPath, Paint()..color = unplayed);
    // Soft glow under the played bars, then the bars themselves.
    canvas.drawPath(
      playedPath,
      Paint()
        ..shader = shader
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
        ..color = Colors.white.withValues(alpha: 0.6),
    );
    canvas.drawPath(playedPath, Paint()..shader = shader);

    // Playhead knob.
    final px = size.width * fraction;
    final r = 5 + 3 * grab.value;
    final knobColor = Color.lerp(played, playedEnd, fraction)!;
    canvas.drawCircle(
      Offset(px, mid),
      r + 6,
      Paint()
        ..color = knobColor.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(Offset(px, mid), r, Paint()..color = knobColor);
    canvas.drawCircle(
      Offset(px, mid),
      r * 0.4,
      Paint()..color = AppColors.ink.withValues(alpha: 0.6),
    );
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.fraction != fraction ||
      old.bars != bars ||
      old.played != played ||
      old.playedEnd != playedEnd ||
      old.unplayed != unplayed ||
      old.energy != energy;
}
