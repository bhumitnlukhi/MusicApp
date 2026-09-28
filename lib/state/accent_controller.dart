import 'dart:async';
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
typedef SongColors = ({Color accent, Color deep});

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
      final seed = await _dominantColor(pixels);
      return seed == null ? fallback : _pairFromSeed(seed);
    } catch (e) {
      debugPrint('Accent extraction failed for ${track.id}: $e');
      return fallback;
    }
  }

  /// The cover's main *color*: groups colorful pixels by hue and picks the
  /// hue family covering the most of the cover (slightly favoring vivid
  /// ones). Greys, blacks, whites and most skin tones are ignored. Returns
  /// null for colorless covers.
  static Future<Hct?> _dominantColor(List<int> pixels) async {
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
    return best[top];
  }

  /// Turns a cover color into a vivid accent + deep background of one hue.
  static SongColors _pairFromSeed(Hct seed) {
    final hue = seed.hue;
    // Yellows/greens only look vivid when very light; other hues get
    // richer a little darker. Chroma is clamped to the sRGB gamut by Hct.
    final isYellowGreen = hue >= 75 && hue <= 150;
    final accent = Hct.from(
      hue,
      max(seed.chroma * 1.5, 70),
      isYellowGreen ? 86 : 74,
    );
    final deep = Hct.from(
      hue,
      (seed.chroma * 0.5).clamp(16, 30).toDouble(),
      12,
    );
    return (accent: Color(accent.toInt()), deep: Color(deep.toInt()));
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
