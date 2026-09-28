import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'common.dart';

/// The lime waveform scrubber from the Now Playing design. The bar heights
/// are decorative (seeded from the track id so each song looks different);
/// drag or tap anywhere to seek.
class WaveformSeekBar extends StatefulWidget {
  const WaveformSeekBar({
    super.key,
    required this.seed,
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  final String seed;
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;

  @override
  State<WaveformSeekBar> createState() => _WaveformSeekBarState();
}

class _WaveformSeekBarState extends State<WaveformSeekBar> {
  static const _barCount = 64;
  late List<double> _bars = _makeBars(widget.seed);

  /// While dragging, show the drag position instead of the player's.
  double? _dragFraction;

  @override
  void didUpdateWidget(WaveformSeekBar old) {
    super.didUpdateWidget(old);
    if (old.seed != widget.seed) _bars = _makeBars(widget.seed);
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

  void _updateDrag(Offset local, double width) =>
      setState(() => _dragFraction = (local.dx / width).clamp(0.0, 1.0));

  void _commit() {
    final f = _dragFraction;
    if (f == null) return;
    widget.onSeek(widget.duration * f);
    setState(() => _dragFraction = null);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final shownPosition = widget.duration * _fraction;
    return Column(
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
                onTapDown: (d) => _updateDrag(d.localPosition, width),
                onTapUp: (_) => _commit(),
                child: SizedBox(
                  height: 44,
                  width: width,
                  child: CustomPaint(
                    painter: _WaveformPainter(
                      bars: _bars,
                      fraction: _fraction,
                      played: p.accent,
                      unplayed: p.border,
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
            Text(
              formatDuration(shownPosition),
              style: AppText.ui(11, color: p.muted),
            ),
            const Spacer(),
            Text(
              formatDuration(widget.duration),
              style: AppText.ui(11, color: p.muted),
            ),
          ],
        ),
      ],
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.bars,
    required this.fraction,
    required this.played,
    required this.unplayed,
  });

  final List<double> bars;
  final double fraction;
  final Color played;
  final Color unplayed;

  @override
  void paint(Canvas canvas, Size size) {
    final slot = size.width / bars.length;
    final barWidth = max(1.5, slot * 0.45);
    final mid = size.height / 2;
    final paint = Paint()..strokeCap = StrokeCap.round;

    for (var i = 0; i < bars.length; i++) {
      final x = slot * i + slot / 2;
      final h = bars[i] * size.height * 0.9;
      paint
        ..color = (x / size.width) <= fraction ? played : unplayed
        ..strokeWidth = barWidth;
      canvas.drawLine(Offset(x, mid - h / 2), Offset(x, mid + h / 2), paint);
    }

    // Playhead.
    final px = size.width * fraction;
    canvas.drawLine(
      Offset(px, 0),
      Offset(px, size.height),
      Paint()
        ..color = played
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.fraction != fraction || old.bars != bars || old.unplayed != unplayed;
}
