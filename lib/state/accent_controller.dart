import 'dart:async';
import 'dart:isolate';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

import '../core/theme/app_theme.dart';
import '../data/models.dart';
import 'player_controller.dart';

/// The colors a song gives the app.
///
/// * [accent] — vivid, bright tone of the cover's main color. Used for
///   pills, the waveform, hearts, play buttons and progress bars; always light
///   enough for ink text/icons on top.
/// * [deep] — a very dark shade of the same hue, used as the background of
///   Now Playing, the queue and the mini player.
/// * [glow] — a second vivid color (the cover's next strongest hue, or a
///   neighbour of [accent]) for gradients and the animated mood backdrop.
/// * [energy] — 0..1 guess at the cover's mood: warm, saturated covers are
///   "energetic" and make the backdrop and waveform move faster.
typedef SongColors = ({Color accent, Color deep, Color glow, double energy});

/// Picks [SongColors] for every song from its album art. Covers with no
/// real color (black & white photos) get a pair from [_neonPalette], chosen by
/// track id so the same song always gets the same colors.
class AccentController extends ChangeNotifier {
  AccentController(this._player) {
    _player.addListener(_onPlayerChanged);
    _onPlayerChanged();
  }

  static const SongColors defaults = (
    accent: AppColors.lime,
    deep: AppColors.inkSurface,
    glow: Color(0xFF3DF2E0),
    energy: 0.5,
  );

  final PlayerController _player;
  final Map<String, SongColors> _cache = {};
  SongColors _colors = defaults;
  String? _trackId;

  SongColors get colors => _colors;
  Color get accent => _colors.accent;

  /// Hand-tuned hues for colorless covers.
  static const _neonPalette = [
    AppColors.lime,
    Color(0xFF3DF2E0), // aqua
    Color(0xFFFF5FA2), // hot pink
    Color(0xFFFF8A3D), // tangerine
    Color(0xFFB69CFF), // lavender
    Color(0xFFFFD23F), // sunflower
    Color(0xFF5CFF9D), // mint
    Color(0xFF5BC8FF), // sky
  ];

  void _onPlayerChanged() {
    final track = _player.current;
    if (track == null || track.id == _trackId) return;
    _trackId = track.id;
    unawaited(_update(track));
  }

  Future<void> _update(Track track) async {
    final colors = _cache[track.id] ??= await _fromArtwork(track);
    // A newer song may have started while the artwork was decoding.
    if (_trackId != track.id || colors == _colors) return;
    _colors = colors;
    notifyListeners();
  }

  Future<SongColors> _fromArtwork(Track track) async {
    final fallback = _pairFromSeed(
      Hct.fromInt(
        _neonPalette[track.id.hashCode.abs() % _neonPalette.length].toARGB32(),
      ),
    );
    if (track.imageUrl.isEmpty) return fallback;
    try {
      // JioSaavn serves each cover in several sizes; the small one is plenty
      // for picking colors and downloads much faster.
      final pixels = await _samplePixels(
        track.imageUrl.replaceFirst('500x500', '150x150'),
      );
      // Color quantizing takes a few ms — off the UI thread, so the song
      // change animations never stutter.
      final seeds = await _dominantColorsInBackground(pixels);
      return seeds == null
          ? fallback
          : _pairFromSeed(seeds.$1, second: seeds.$2);
    } catch (e) {
      debugPrint('Accent extraction failed for ${track.id}: $e');
      return fallback;
    }
  }

  /// [_dominantColors] on a background isolate. Static, so the closure only
  /// captures [pixels] (not this controller, which can't be sent).
  static Future<(Hct, Hct?)?> _dominantColorsInBackground(List<int> pixels) =>
      Isolate.run(() => _dominantColors(pixels));

  /// The cover's main *color*: groups colorful pixels by hue and picks the
  /// hue family covering the most of the cover (slightly favoring vivid
  /// ones). Greys, blacks, whites and most skin tones are ignored. Also
  /// returns the strongest clearly different hue, if any. Returns null for
  /// colorless covers.
  static Future<(Hct, Hct?)?> _dominantColors(List<int> pixels) async {
    if (pixels.isEmpty) return null;
    final quantized = await QuantizerCelebi().quantize(pixels, 48);

    const buckets = 24; // 15° of hue each
    final weight = List<double>.filled(buckets, 0);
    final best = List<Hct?>.filled(buckets, null);
    final bestCount = List<int>.filled(buckets, 0);
    var colorful = 0;

    quantized.colorToCount.forEach((argb, count) {
      final hct = Hct.fromInt(argb);
      if (hct.chroma < 24 || hct.tone < 18 || hct.tone > 92) return;
      colorful += count;
      final b = (hct.hue / (360 / buckets)).floor() % buckets;
      weight[b] += count * (0.6 + min(hct.chroma, 90) / 90);
      if (count > bestCount[b]) {
        bestCount[b] = count;
        best[b] = hct;
      }
    });

    // Under ~6% colorful pixels → treat as a black & white cover.
    if (colorful < pixels.length * 0.06) return null;

    var top = 0;
    for (var b = 1; b < buckets; b++) {
      if (weight[b] > weight[top]) top = b;
    }

    // Second hue: at least 45° away and a meaningful part of the cover.
    int? second;
    for (var b = 0; b < buckets; b++) {
      final distance = min((b - top).abs(), buckets - (b - top).abs());
      if (distance < 3 || weight[b] < weight[top] * 0.18) continue;
      if (second == null || weight[b] > weight[second]) second = b;
    }
    return (best[top]!, second == null ? null : best[second]);
  }

  /// Turns a cover color into a vivid accent + deep background of one hue,
  /// plus a glow color from [second] (or a neighbouring hue).
  static SongColors _pairFromSeed(Hct seed, {Hct? second}) {
    final hue = seed.hue;
    final accent = _vivid(hue, seed.chroma);
    final deep = Hct.from(
      hue,
      (seed.chroma * 0.5).clamp(16, 30).toDouble(),
      12,
    );
    final glow = second != null
        ? _vivid(second.hue, second.chroma)
        : _vivid((hue + 42) % 360, seed.chroma);

    // Reds/oranges/magentas feel energetic, blues/greens calm.
    final warmth = (cos((hue - 30) * pi / 180) + 1) / 2;
    final energy = (0.2 + min(seed.chroma, 100) / 100 * 0.45 + warmth * 0.35)
        .clamp(0.0, 1.0)
        .toDouble();

    return (
      accent: Color(accent.toInt()),
      deep: Color(deep.toInt()),
      glow: Color(glow.toInt()),
      energy: energy,
    );
  }

  /// Bright tone of [hue], light enough for ink text on top. Yellows/greens
  /// only look vivid when very light; other hues get richer a little darker.
  /// Chroma is clamped to the sRGB gamut by Hct.
  static Hct _vivid(double hue, double chroma) {
    final isYellowGreen = hue >= 75 && hue <= 150;
    return Hct.from(hue, max(chroma * 1.5, 70), isYellowGreen ? 86 : 74);
  }

  /// Decodes the (already cached) artwork at 48×48 and returns ARGB pixels.
  Future<List<int>> _samplePixels(String url) async {
    final provider = ResizeImage(
      CachedNetworkImageProvider(url),
      width: 48,
      height: 48,
    );
    final completer = Completer<ImageInfo>();
    final stream = provider.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        stream.removeListener(listener);
        completer.complete(info);
      },
      onError: (error, stack) {
        stream.removeListener(listener);
        completer.completeError(error, stack);
      },
    );
    stream.addListener(listener);

    final info = await completer.future;
    try {
      final data = await info.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (data == null) return const [];
      final pixels = <int>[];
      for (var i = 0; i + 3 < data.lengthInBytes; i += 4) {
        final a = data.getUint8(i + 3);
        if (a < 255) continue; // skip transparent pixels
        pixels.add(
          (a << 24) |
              (data.getUint8(i) << 16) |
              (data.getUint8(i + 1) << 8) |
              data.getUint8(i + 2),
        );
      }
      return pixels;
    } finally {
      info.dispose();
    }
  }

  @override
  void dispose() {
    _player.removeListener(_onPlayerChanged);
    super.dispose();
  }
}
