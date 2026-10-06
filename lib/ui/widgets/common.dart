import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'motion.dart';

/// Cover art / artist photo with a flat placeholder while loading.
class Artwork extends StatelessWidget {
  const Artwork({
    super.key,
    required this.url,
    this.size,
    this.radius = 4,
    this.circle = false,
    this.icon = Icons.music_note_rounded,
  });

  final String url;

  /// Null = fill the parent's constraints.
  final double? size;
  final double radius;
  final bool circle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final placeholder = Container(
      color: p.surface,
      alignment: Alignment.center,
      child: Icon(icon, color: p.muted, size: (size ?? 48) * 0.4),
    );
    final dpr = MediaQuery.devicePixelRatioOf(context);
    Widget image = url.isEmpty
        ? placeholder
        : CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            memCacheWidth: size == null ? null : (size! * dpr).round(),
            placeholder: (_, _) => placeholder,
            errorWidget: (_, _, _) => placeholder,
            fadeInDuration: const Duration(milliseconds: 200),
          );
    image = circle
        ? ClipOval(child: image)
        : ClipRRect(borderRadius: BorderRadius.circular(radius), child: image);
    return SizedBox(width: size, height: size, child: image);
  }
}

/// The small "01 //" label above each big screen title.
class ScreenLabel extends StatelessWidget {
  const ScreenLabel(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
    '$text //',
    style: AppText.ui(
      11,
      weight: FontWeight.w600,
      color: color ?? context.palette.fg,
      letterSpacing: 0.5,
    ),
  );
}

/// Huge condensed uppercase headline ("DISCOVER", "YOUR LIBRARY").
class DisplayTitle extends StatelessWidget {
  const DisplayTitle(
    this.text, {
    super.key,
    this.size = 48,
    this.color,
    this.maxLines,
  });

  final String text;
  final double size;
  final Color? color;
  final int? maxLines;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    maxLines: maxLines,
    overflow: maxLines == null ? null : TextOverflow.ellipsis,
    style: AppText.display(size, color: color ?? context.palette.fg),
  );
}

/// Top-of-screen block: label + optional actions, then the big title.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.label,
    required this.title,
    this.actions = const [],
  });

  final String label;
  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: ScreenLabel(label)),
              ...actions,
            ],
          ),
          const SizedBox(height: 4),
          Entrance(offset: 18, child: DisplayTitle(title, maxLines: 2)),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.onSeeAll});

  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: AppText.ui(15, weight: FontWeight.w600, color: p.fg),
            ),
          ),
          if (onSeeAll != null)
            Pressable(
              onTap: onSeeAll,
              tilt: 0,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'See All',
                  style: AppText.ui(11, weight: FontWeight.w500, color: p.fg),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Horizontal filter tabs; the selected one is a lime pill.
class PillTabs extends StatelessWidget {
  const PillTabs({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onChanged,
  });

  final List<String> tabs;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        clipBehavior: Clip.none,
        itemCount: tabs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final isSelected = i == selected;
          final fill = p.isDark ? p.accent : AppColors.ink;
          return Pressable(
            onTap: () => onChanged(i),
            scale: 0.9,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? fill : p.fg.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? Colors.transparent
                      : p.fg.withValues(alpha: 0.08),
                ),
                boxShadow: [
                  if (isSelected && p.isDark)
                    BoxShadow(
                      color: p.accent.withValues(alpha: 0.35),
                      blurRadius: 14,
                      spreadRadius: -4,
                      offset: const Offset(0, 4),
                    ),
                ],
              ),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 380),
                style: AppText.ui(
                  12,
                  weight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? (p.isDark ? AppColors.ink : AppColors.paper)
                      : p.fg,
                ),
                child: Text(tabs[i]),
              ),
            ),
          );
        },
      ),
    );
  }
}

enum PlayButtonStyle { lime, ink, paper }

/// Circular play/pause button used on headers and cards.
class RoundPlayButton extends StatelessWidget {
  const RoundPlayButton({
    super.key,
    required this.onTap,
    this.size = 44,
    this.style = PlayButtonStyle.ink,
    this.playing = false,
  });

  final VoidCallback? onTap;
  final double size;
  final PlayButtonStyle style;
  final bool playing;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (style) {
      PlayButtonStyle.lime => (context.palette.accent, AppColors.ink),
      PlayButtonStyle.ink => (AppColors.ink, AppColors.paper),
      PlayButtonStyle.paper => (AppColors.paper, AppColors.ink),
    };
    final p = context.palette;
    return Semantics(
      button: true,
      label: playing ? 'Pause' : 'Play',
      child: Pressable(
        onTap: onTap,
        scale: 0.88,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            gradient: style == PlayButtonStyle.lime
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [p.accent, Color.lerp(p.accent, p.glow, 0.6)!],
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: (style == PlayButtonStyle.ink ? Colors.black : p.accent)
                    .withValues(
                      alpha: style == PlayButtonStyle.paper ? 0 : 0.3,
                    ),
                blurRadius: 18,
                spreadRadius: -4,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: PlayPauseIcon(playing: playing, color: fg, size: size * 0.5),
          ),
        ),
      ),
    );
  }
}

/// Compact icon button without Material's big padding.
class IconBtn extends StatelessWidget {
  const IconBtn(
    this.icon, {
    super.key,
    required this.onTap,
    this.size = 22,
    this.color,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color? color;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      icon: Icon(icon, size: size, color: color ?? context.palette.fg),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.height = 160});

  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: const Center(
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
  );
}

class MessageView extends StatelessWidget {
  const MessageView({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final content = Entrance(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: p.muted),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppText.ui(15, weight: FontWeight.w600, color: p.fg),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: AppText.ui(13, color: p.muted),
              ),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  foregroundColor: p.fg,
                  side: BorderSide(color: p.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
    // In a box of fixed height (an empty tab, a short screen), scroll
    // instead of overflowing.
    return LayoutBuilder(
      builder: (context, constraints) => constraints.hasBoundedHeight
          ? SingleChildScrollView(
              child: SizedBox(width: constraints.maxWidth, child: content),
            )
          : content,
    );
  }
}

/// Runs [load] once and shows loading / error-with-retry / data states.
class AsyncView<T> extends StatefulWidget {
  const AsyncView({
    super.key,
    required this.load,
    required this.builder,
    this.loading,
  });

  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data) builder;
  final Widget? loading;

  @override
  State<AsyncView<T>> createState() => _AsyncViewState<T>();
}

class _AsyncViewState<T> extends State<AsyncView<T>> {
  late Future<T> _future = widget.load();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return MessageView(
            icon: Icons.wifi_off_rounded,
            title: "Couldn't load this",
            subtitle: 'Check your connection and try again.',
            actionLabel: 'Retry',
            onAction: () => setState(() => _future = widget.load()),
          );
        }
        if (!snap.hasData) return widget.loading ?? const LoadingView();
        return widget.builder(context, snap.data as T);
      },
    );
  }
}

String formatDuration(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// 1234567 → "1.2M".
String formatCount(int n) {
  if (n >= 1000000000) return '${(n / 1e9).toStringAsFixed(1)}B';
  if (n >= 1000000) return '${(n / 1e6).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1e3).toStringAsFixed(1)}K';
  return '$n';
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
}
