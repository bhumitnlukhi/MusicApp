import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Shared durations and curves so every animation in the app feels the same.
class Motion {
  Motion._();

  static const fast = Duration(milliseconds: 180);
  static const medium = Duration(milliseconds: 320);
  static const slow = Duration(milliseconds: 520);

  /// Material 3 "emphasized decelerate": quick start, long soft landing.
  static const decelerate = Cubic(0.05, 0.7, 0.1, 1.0);

  /// Material 3 "emphasized" in/out, for things that move across the screen.
  static const emphasized = Cubic(0.2, 0.0, 0.0, 1.0);

  /// Perspective strength for 3D transforms.
  static const depth = 0.0012;

  static Matrix4 perspective() => Matrix4.identity()..setEntry(3, 2, depth);

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

/// Small version of a JioSaavn cover — plenty for blurred backdrops.
String smallArt(String url) => url.replaceFirst('500x500', '150x150');

// ---------------------------------------------------------------------------
// Route transitions
// ---------------------------------------------------------------------------

/// Pushed screens swing in from the right like a door opening in 3D, while
/// the screen underneath sinks back, rounds its corners and dims.
class DepthPageTransitionsBuilder extends PageTransitionsBuilder {
  const DepthPageTransitionsBuilder();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 520);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 420);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => RecedeTransition(
    animation: secondaryAnimation,
    child: AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final t = Motion.decelerate.transform(animation.value);
        final hidden = 1 - t;
        return FractionalTranslation(
          translation: Offset(hidden, 0),
          child: Transform(
            alignment: Alignment.centerLeft,
            transform: Motion.perspective()..rotateY(-hidden * 0.55),
            child: DecoratedBox(
              decoration: BoxDecoration(
                boxShadow: [
                  if (hidden > 0)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45 * t),
                      blurRadius: 32,
                      offset: const Offset(-8, 0),
                    ),
                ],
              ),
              child: child,
            ),
          ),
        );
      },
    ),
  );
}

/// The screen under a newly pushed one: scales down, rounds its corners and
/// darkens as [animation] (the route's secondary animation) runs.
class RecedeTransition extends StatelessWidget {
  const RecedeTransition({
    super.key,
    required this.animation,
    required this.child,
  });

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    child: child,
    builder: (context, child) {
      final s = Curves.easeOutCubic.transform(animation.value);
      // Keep the widget tree identical at rest so page state is preserved.
      return Transform(
        alignment: Alignment.center,
        transform: Motion.perspective()
          ..scaleByDouble(1 - 0.08 * s, 1 - 0.08 * s, 1, 1)
          ..rotateX(0.06 * s),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28 * s),
          clipBehavior: s == 0 ? Clip.none : Clip.antiAlias,
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55 * s),
            ),
            child: child,
          ),
        ),
      );
    },
  );
}

/// Full-screen player sheets (Now Playing, Lyrics, Queue): rise from the
/// bottom tilting up into place like a card, while the previous screen
/// recedes behind them.
class SheetPageRoute<T> extends MaterialPageRoute<T> {
  SheetPageRoute({required super.builder});

  @override
  Duration get transitionDuration => const Duration(milliseconds: 560);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 420);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => RecedeTransition(
    animation: secondaryAnimation,
    child: AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final t = Motion.decelerate.transform(animation.value);
        final hidden = 1 - t;
        return FractionalTranslation(
          translation: Offset(0, hidden * 0.9),
          child: Transform(
            alignment: Alignment.bottomCenter,
            transform: Motion.perspective()
              ..rotateX(-hidden * 0.45)
              ..scaleByDouble(1 - hidden * 0.1, 1 - hidden * 0.1, 1, 1),
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(32 * hidden),
              ),
              clipBehavior: hidden == 0 ? Clip.none : Clip.antiAlias,
              child: Opacity(opacity: (t * 2).clamp(0.0, 1.0), child: child),
            ),
          ),
        );
      },
    ),
  );
}

// ---------------------------------------------------------------------------
// Touch feedback & entrances
// ---------------------------------------------------------------------------

/// Tap target that sinks in 3D toward the finger when pressed and springs
/// back on release.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.95,
    this.tilt = 0.14,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Scale at full press.
  final double scale;

  /// Max tilt (radians) toward the touch point.
  final double tilt;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this);
  Offset _touch = Offset.zero; // -1..1 in both axes

  void _down(TapDownDetails d) {
    final size = context.size;
    if (size != null && size.width > 0 && size.height > 0) {
      _touch = Offset(
        (d.localPosition.dx / size.width * 2 - 1).clamp(-1.0, 1.0),
        (d.localPosition.dy / size.height * 2 - 1).clamp(-1.0, 1.0),
      );
    }
    _c.animateTo(1, duration: Motion.fast, curve: Curves.easeOutCubic);
  }

  void _up([Object? _]) => _c.animateTo(
    0,
    duration: const Duration(milliseconds: 520),
    curve: Curves.easeOutBack,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: enabled ? _down : null,
      onTapUp: enabled ? _up : null,
      onTapCancel: enabled ? _up : null,
      child: AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (context, child) {
          final v = _c.value;
          final s = 1 - (1 - widget.scale) * v;
          return Transform(
            alignment: Alignment.center,
            transform: Motion.perspective()
              ..rotateX(_touch.dy * widget.tilt * v)
              ..rotateY(-_touch.dx * widget.tilt * v)
              ..scaleByDouble(s, s, 1, 1),
            child: child,
          );
        },
      ),
    );
  }
}

/// Fades a widget in while it rises and un-tilts from below. [index]
/// staggers items in a list (only the first few are delayed, so content
/// scrolled into view later appears instantly).
class Entrance extends StatefulWidget {
  const Entrance({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = 28,
    this.duration = const Duration(milliseconds: 560),
  });

  final Widget child;
  final int index;
  final double offset;
  final Duration duration;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.duration);
  Timer? _delay;

  @override
  void initState() {
    super.initState();
    final i = widget.index;
    if (i <= 0 || i > 12) {
      _c.forward();
    } else {
      _delay = Timer(Duration(milliseconds: 45 * i), _c.forward);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) _c.value = 1;
  }

  @override
  void dispose() {
    _delay?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    builder: (context, child) {
      final t = Motion.decelerate.transform(_c.value);
      return Opacity(
        opacity: Curves.easeOut.transform(_c.value),
        child: Transform(
          alignment: Alignment.topCenter,
          transform: Motion.perspective()
            ..translateByDouble(0, (1 - t) * widget.offset, 0, 1)
            ..rotateX((1 - t) * 0.35),
          child: child,
        ),
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Little animated pieces
// ---------------------------------------------------------------------------

/// Play ⇄ pause icon that morphs instead of swapping.
class PlayPauseIcon extends StatefulWidget {
  const PlayPauseIcon({
    super.key,
    required this.playing,
    this.size = 28,
    this.color,
  });

  final bool playing;
  final double size;
  final Color? color;

  @override
  State<PlayPauseIcon> createState() => _PlayPauseIconState();
}

class _PlayPauseIconState extends State<PlayPauseIcon>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: Motion.medium,
    value: widget.playing ? 1 : 0,
  );

  @override
  void didUpdateWidget(PlayPauseIcon old) {
    super.didUpdateWidget(old);
    if (old.playing != widget.playing) {
      _c.animateTo(widget.playing ? 1 : 0, curve: Curves.easeInOutCubic);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedIcon(
    icon: AnimatedIcons.play_pause,
    progress: _c,
    size: widget.size,
    color: widget.color ?? context.palette.fg,
    semanticLabel: widget.playing ? 'Pause' : 'Play',
  );
}

/// Bouncing equalizer bars — the "this song is playing" indicator.
class EqualizerBars extends StatefulWidget {
  const EqualizerBars({
    super.key,
    required this.playing,
    this.color,
    this.size = 16,
    this.bars = 4,
  });

  final bool playing;
  final Color? color;
  final double size;
  final int bars;

  @override
  State<EqualizerBars> createState() => _EqualizerBarsState();
}

class _EqualizerBarsState extends State<EqualizerBars>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.playing) _c.repeat();
  }

  @override
  void didUpdateWidget(EqualizerBars old) {
    super.didUpdateWidget(old);
    if (widget.playing && !_c.isAnimating) _c.repeat();
    if (!widget.playing && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      size: Size.square(widget.size),
      painter: _EqualizerPainter(
        _c,
        color: widget.color ?? context.palette.accentText,
        bars: widget.bars,
        playing: widget.playing,
      ),
    ),
  );
}

class _EqualizerPainter extends CustomPainter {
  _EqualizerPainter(
    this.anim, {
    required this.color,
    required this.bars,
    required this.playing,
  }) : super(repaint: anim);

  final Animation<double> anim;
  final Color color;
  final int bars;
  final bool playing;

  @override
  void paint(Canvas canvas, Size size) {
    final gap = size.width / (bars * 2 - 1);
    final paint = Paint()
      ..color = color
      ..strokeWidth = gap
      ..strokeCap = StrokeCap.round;
    final t = anim.value * 2 * math.pi;
    for (var i = 0; i < bars; i++) {
      final wave = playing
          ? 0.5 +
                0.5 *
                    math.sin(t * (2 + i * 0.7) + i * 1.9) *
                    math.cos(t * (1 + i * 0.3))
          : 0.15;
      final h = size.height * (0.2 + 0.8 * wave.abs());
      final x = gap / 2 + i * gap * 2;
      canvas.drawLine(
        Offset(x, size.height - gap / 2),
        Offset(x, size.height - h + gap / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_EqualizerPainter old) =>
      old.color != color || old.playing != playing;
}

/// Heart that pops with a little burst when liked.
class HeartButton extends StatefulWidget {
  const HeartButton({
    super.key,
    required this.liked,
    required this.onTap,
    this.size = 24,
    this.color,
  });

  final bool liked;
  final VoidCallback onTap;
  final double size;

  /// Unliked color; liked hearts use the accent.
  final Color? color;

  @override
  State<HeartButton> createState() => _HeartButtonState();
}

class _HeartButtonState extends State<HeartButton>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
    value: 1,
  );

  static final _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1,
        end: 0.6,
      ).chain(CurveTween(curve: Curves.easeIn)),
      weight: 15,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 0.6,
        end: 1.35,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 35,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1.35,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.elasticOut)),
      weight: 50,
    ),
  ]);

  @override
  void didUpdateWidget(HeartButton old) {
    super.didUpdateWidget(old);
    if (widget.liked && !old.liked) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final accent = p.isDark ? p.accent : AppColors.ink;
    return IconButton(
      onPressed: widget.onTap,
      tooltip: widget.liked ? 'Unlike' : 'Like',
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      icon: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final v = _c.value;
          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Expanding ring.
              if (v < 1 && widget.liked)
                Container(
                  width: widget.size * (0.6 + v * 1.2),
                  height: widget.size * (0.6 + v * 1.2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: accent.withValues(alpha: (1 - v) * 0.8),
                      width: 2 * (1 - v),
                    ),
                  ),
                ),
              Transform.scale(
                scale: _scale.transform(v),
                child: Icon(
                  widget.liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: widget.size,
                  color: widget.liked ? accent : (widget.color ?? p.fg),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mood backdrop
// ---------------------------------------------------------------------------

/// Living background in the song's colors: a heavily blurred copy of the
/// cover with slow drifting blobs of accent and glow light on top, fading to
/// the screen background at the bottom. Drift speed follows the song's
/// energy; it only moves while [animate] is true.
class MoodBackdrop extends StatefulWidget {
  const MoodBackdrop({
    super.key,
    this.imageUrl,
    this.animate = true,
    this.intensity = 1,
    this.fadeTo,
  });

  /// Cover to blur in the background. Null = blobs only.
  final String? imageUrl;
  final bool animate;

  /// 0..1 strength of the colors.
  final double intensity;

  /// Color at the bottom of the backdrop (defaults to the screen bg).
  final Color? fadeTo;

  @override
  State<MoodBackdrop> createState() => _MoodBackdropState();
}

class _MoodBackdropState extends State<MoodBackdrop>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  );

  void _sync() {
    // Energetic songs drift faster (one loop in ~12s) than calm ones (~30s).
    final period = Duration(
      seconds: (30 - 18 * context.palette.energy).round(),
    );
    final run = widget.animate && !Motion.reduced(context);
    if (period != _c.duration) {
      _c.duration = period;
      if (run) _c.repeat(); // continues from the current phase
    }
    if (run && !_c.isAnimating) _c.repeat();
    if (!run && _c.isAnimating) _c.stop();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(MoodBackdrop old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final url = widget.imageUrl;
    final fadeTo = widget.fadeTo ?? p.bg;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: Color.lerp(p.bg, p.accentDeep, widget.intensity)!),
        if (url != null && url.isNotEmpty)
          RepaintBoundary(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 1100),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              layoutBuilder: (current, previous) => Stack(
                fit: StackFit.expand,
                children: [...previous, ?current],
              ),
              child: BlurredArt(
                key: ValueKey(url),
                url: url,
                opacity: 0.55 * widget.intensity,
              ),
            ),
          ),
        RepaintBoundary(
          child: CustomPaint(
            painter: _BlobPainter(
              _c,
              accent: p.accent,
              glow: p.glow,
              deep: p.accentDeep,
              intensity: widget.intensity,
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.25),
                Colors.transparent,
                fadeTo.withValues(alpha: 0.85),
                fadeTo,
              ],
              stops: const [0, 0.3, 0.82, 1],
            ),
          ),
        ),
      ],
    );
  }
}

class _BlobPainter extends CustomPainter {
  _BlobPainter(
    this.anim, {
    required this.accent,
    required this.glow,
    required this.deep,
    required this.intensity,
  }) : super(repaint: anim);

  final Animation<double> anim;
  final Color accent;
  final Color glow;
  final Color deep;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value * 2 * math.pi;
    final w = size.width;
    final h = size.height;
    final r = math.max(w, h * 0.6);

    void blob(Color color, double alpha, Offset c, double radius) {
      final rect = Rect.fromCircle(center: c, radius: radius);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: alpha * intensity),
              color.withValues(alpha: 0),
            ],
          ).createShader(rect),
      );
    }

    blob(
      accent,
      0.42,
      Offset(
        w * (0.25 + 0.2 * math.sin(t)),
        h * (0.18 + 0.08 * math.cos(t * 2)),
      ),
      r * 0.75,
    );
    blob(
      glow,
      0.34,
      Offset(
        w * (0.8 + 0.18 * math.cos(t + 1.3)),
        h * (0.32 + 0.1 * math.sin(t * 2 + 0.7)),
      ),
      r * 0.65,
    );
    blob(
      Color.lerp(accent, deep, 0.5)!,
      0.3,
      Offset(
        w * (0.5 + 0.3 * math.sin(t * 2 + 2.1)),
        h * (0.55 + 0.06 * math.cos(t + 0.4)),
      ),
      r * 0.6,
    );
  }

  @override
  bool shouldRepaint(_BlobPainter old) =>
      old.accent != accent ||
      old.glow != glow ||
      old.deep != deep ||
      old.intensity != intensity;
}

/// Cover art blurred once at low resolution, cached, then stretched to fill.
/// Looks the same as a full-screen blur filter, but a live filter re-runs
/// on every frame that anything animates above it; this costs nothing per
/// frame.
class BlurredArt extends StatefulWidget {
  const BlurredArt({super.key, required this.url, this.opacity = 1});

  final String url;
  final double opacity;

  @override
  State<BlurredArt> createState() => _BlurredArtState();
}

class _BlurredArtState extends State<BlurredArt> {
  static final _cache = <String, Future<ui.Image?>>{};

  /// Size of the blurred bitmap; smooth enough once stretched.
  static const _side = 64;

  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(BlurredArt old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) _load();
  }

  void _load() {
    final url = widget.url;
    if (_cache.length > 24) _cache.remove(_cache.keys.first);
    _cache.putIfAbsent(url, () => _blur(url)).then((image) {
      if (image == null) _cache.remove(url); // retry next time
      if (mounted && widget.url == url) setState(() => _image = image);
    });
  }

  static Future<ui.Image?> _blur(String url) async {
    final completer = Completer<ImageInfo>();
    final stream = ResizeImage(
      CachedNetworkImageProvider(smallArt(url)),
      width: 48,
      height: 48,
    ).resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        stream.removeListener(listener);
        if (!completer.isCompleted) completer.complete(info);
      },
      onError: (error, stack) {
        stream.removeListener(listener);
        if (!completer.isCompleted) completer.completeError(error, stack);
      },
    );
    stream.addListener(listener);

    try {
      final info = await completer.future;
      try {
        final src = info.image;
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawImageRect(
          src,
          Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()),
          const Rect.fromLTWH(0, 0, _side + 0.0, _side + 0.0),
          Paint()
            ..filterQuality = FilterQuality.medium
            // Same softness as a 48px blur on a full-screen cover.
            ..imageFilter = ui.ImageFilter.blur(
              sigmaX: 4.5,
              sigmaY: 4.5,
              tileMode: TileMode.clamp,
            ),
        );
        final picture = recorder.endRecording();
        final blurred = await picture.toImage(_side, _side);
        picture.dispose();
        return blurred;
      } finally {
        info.dispose();
      }
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: _image == null ? 0 : 1,
    duration: const Duration(milliseconds: 400),
    child: _image == null
        ? const SizedBox.expand()
        : RawImage(
            image: _image,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            filterQuality: FilterQuality.medium,
            color: Colors.white.withValues(alpha: widget.opacity),
            colorBlendMode: BlendMode.modulate,
          ),
  );
}
