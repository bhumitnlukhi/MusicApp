import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../state/accent_controller.dart';
import '../../ui/widgets/motion.dart';

/// Brand colors from the design: near-black "ink", warm off-white "paper",
/// and a single neon-lime accent.
class AppColors {
  AppColors._();

  static const lime = Color(0xFFD9F21E);
  static const ink = Color(0xFF0E0E0E);
  static const inkSurface = Color(0xFF1B1B1B);
  static const inkBorder = Color(0xFF2B2B2B);
  static const paper = Color(0xFFECE9E2);
  static const paperSurface = Color(0xFFE0DDD5);
  static const paperBorder = Color(0xFFCCC8BF);
  static const mutedOnInk = Color(0xFF8F8F89);
  static const mutedOnPaper = Color(0xFF6E6B64);
}

/// Colors that flip between the dark and light screens. Read with
/// `context.palette`.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.bg,
    required this.fg,
    required this.muted,
    required this.surface,
    required this.border,
    required this.isDark,
    this.accent = AppColors.lime,
    this.accentDeep = AppColors.inkSurface,
    this.glow = const Color(0xFF3DF2E0),
    this.energy = 0.5,
  });

  final Color bg;
  final Color fg;
  final Color muted;
  final Color surface;
  final Color border;
  final bool isDark;

  /// The current song's accent (lime until something plays). Always bright,
  /// so ink text/icons read on top of it.
  final Color accent;

  /// Very dark shade of the accent's hue — background for the player screens.
  final Color accentDeep;

  /// Second vivid color of the song, for gradients and mood backdrops.
  final Color glow;

  /// 0..1 mood of the song's cover (calm → energetic). Scales motion speed.
  final double energy;

  /// Accent used for text/icons: a bright accent reads on ink but not on
  /// paper, so light screens fall back to ink.
  Color get accentText => isDark ? accent : AppColors.ink;

  static const dark = AppPalette(
    bg: AppColors.ink,
    fg: AppColors.paper,
    muted: AppColors.mutedOnInk,
    surface: AppColors.inkSurface,
    border: AppColors.inkBorder,
    isDark: true,
  );

  static const light = AppPalette(
    bg: AppColors.paper,
    fg: AppColors.ink,
    muted: AppColors.mutedOnPaper,
    surface: AppColors.paperSurface,
    border: AppColors.paperBorder,
    isDark: false,
  );

  @override
  AppPalette copyWith({
    Color? bg,
    Color? fg,
    Color? muted,
    Color? surface,
    Color? border,
    bool? isDark,
    Color? accent,
    Color? accentDeep,
    Color? glow,
    double? energy,
  }) => AppPalette(
    bg: bg ?? this.bg,
    fg: fg ?? this.fg,
    muted: muted ?? this.muted,
    surface: surface ?? this.surface,
    border: border ?? this.border,
    isDark: isDark ?? this.isDark,
    accent: accent ?? this.accent,
    accentDeep: accentDeep ?? this.accentDeep,
    glow: glow ?? this.glow,
    energy: energy ?? this.energy,
  );

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    return AppPalette(
      bg: Color.lerp(bg, other.bg, t)!,
      fg: Color.lerp(fg, other.fg, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      border: Color.lerp(border, other.border, t)!,
      isDark: t < 0.5 ? isDark : other.isDark,
      accent: Color.lerp(accent, other.accent, t)!,
      accentDeep: Color.lerp(accentDeep, other.accentDeep, t)!,
      glow: Color.lerp(glow, other.glow, t)!,
      energy: energy + (other.energy - energy) * t,
    );
  }
}

extension PaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}

/// Typography: condensed Bebas Neue for big headlines, Inter for UI text,
/// JetBrains Mono for lyrics.
class AppText {
  AppText._();

  static TextStyle display(double size, {Color? color}) =>
      GoogleFonts.bebasNeue(
        fontSize: size,
        height: 0.92,
        letterSpacing: 0.5,
        color: color,
      );

  static TextStyle mono(double size, {Color? color, FontWeight? weight}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        height: 1.55,
        color: color,
        fontWeight: weight,
      );

  static TextStyle ui(
    double size, {
    Color? color,
    FontWeight weight = FontWeight.w400,
    double? letterSpacing,
    double? height,
  }) => GoogleFonts.inter(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );
}

class AppTheme {
  AppTheme._();

  static final dark = _build(AppPalette.dark);
  static final light = _build(AppPalette.light);

  static final _cache = <(bool, SongColors), ThemeData>{};

  /// Theme for a dark or light screen with the given accent. Cached, since
  /// every screen asks for it on each song change.
  static ThemeData of({
    required bool dark,
    SongColors colors = AccentController.defaults,
  }) {
    if (_cache.length > 24) _cache.clear();
    return _cache.putIfAbsent(
      (dark, colors),
      () => _build(
        (dark ? AppPalette.dark : AppPalette.light).copyWith(
          accent: colors.accent,
          accentDeep: colors.deep,
          glow: colors.glow,
          energy: colors.energy,
        ),
      ),
    );
  }

  static ThemeData _build(AppPalette p) {
    final brightness = p.isDark ? Brightness.dark : Brightness.light;
    final base = ThemeData(brightness: brightness, useMaterial3: true);
    final text = GoogleFonts.interTextTheme(
      base.textTheme,
    ).apply(bodyColor: p.fg, displayColor: p.fg);

    return base.copyWith(
      scaffoldBackgroundColor: p.bg,
      canvasColor: p.bg,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: p.accent,
        onPrimary: AppColors.ink,
        secondary: p.fg,
        onSecondary: p.bg,
        error: const Color(0xFFE5484D),
        onError: Colors.white,
        surface: p.bg,
        onSurface: p.fg,
        onSurfaceVariant: p.muted,
        surfaceContainerHighest: p.surface,
        outline: p.border,
      ),
      textTheme: text,
      iconTheme: IconThemeData(color: p.fg, size: 22),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
      splashFactory: NoSplash.splashFactory,
      // 3D depth transition for every pushed screen, on every platform.
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          for (final platform in TargetPlatform.values)
            platform: const DepthPageTransitionsBuilder(),
        },
      ),
      highlightColor: p.fg.withValues(alpha: 0.04),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.fg,
        selectionColor: p.accent.withValues(alpha: 0.5),
        selectionHandleColor: p.fg,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.bg,
        modalBackgroundColor: p.bg,
        showDragHandle: true,
        dragHandleColor: p.border,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.isDark ? AppColors.paper : AppColors.ink,
        contentTextStyle: AppText.ui(
          13,
          color: p.isDark ? AppColors.ink : AppColors.paper,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        hintStyle: AppText.ui(13, color: p.muted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: p.fg),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.isDark ? p.accent : AppColors.ink,
      ),
      extensions: [p],
    );
  }
}

/// Every screen in the design is either dark (ink) or light (paper). Wrap a
/// screen in this to give it the right theme and status-bar icon color. The
/// accent follows the playing song and fades smoothly when it changes.
class ThemedScreen extends StatelessWidget {
  const ThemedScreen({super.key, required this.dark, required this.child});

  final bool dark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.select<AccentController, SongColors>(
      (a) => a.colors,
    );
    return AnimatedTheme(
      data: AppTheme.of(dark: dark, colors: colors),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOutCubic,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
            .copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: dark ? AppColors.ink : AppColors.paper,
            ),
        child: child,
      ),
    );
  }
}
