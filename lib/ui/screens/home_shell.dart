import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../state/player_controller.dart';
import '../widgets/common.dart';
import '../widgets/mini_player.dart';
import '../widgets/motion.dart';
import 'collection_screen.dart';
import 'discover_screen.dart';
import 'library_screen.dart';
import 'search_screen.dart';

/// The four bottom-nav tabs. Each tab keeps its scroll state (IndexedStack),
/// and the nav bar takes the current tab's light/dark theme.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  // Discover and Library are dark; Search and Liked are light.
  static const _tabIsDark = [true, false, true, false];

  int _tab = 0;
  final _searchFocus = FocusNode();
  StreamSubscription<String>? _errorSub;

  @override
  void initState() {
    super.initState();
    _errorSub = context.read<PlayerController>().errors.listen((message) {
      if (mounted) showSnack(context, message);
    });
  }

  @override
  void dispose() {
    _errorSub?.cancel();
    _searchFocus.dispose();
    super.dispose();
  }

  void _select(int i) {
    if (i != 1) _searchFocus.unfocus();
    setState(() => _tab = i);
  }

  @override
  Widget build(BuildContext context) {
    final dark = _tabIsDark[_tab];
    return ThemedScreen(
      dark: dark,
      child: Scaffold(
        body: _TabStack(
          index: _tab,
          children: [
            DiscoverScreen(
              onOpenSearch: () {
                _select(1);
                _searchFocus.requestFocus();
              },
            ),
            SearchScreen(focusNode: _searchFocus),
            const LibraryScreen(),
            const CollectionScreen(source: LikedSource(), embedded: true),
          ],
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MiniPlayer(),
            _BottomNav(selected: _tab, onSelect: _select),
          ],
        ),
      ),
    );
  }
}

/// Like an [IndexedStack] (every tab keeps its state), but the incoming tab
/// fades in while rising slightly forward in depth.
class _TabStack extends StatelessWidget {
  const _TabStack({required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < children.length; i++)
          _TabPage(key: ValueKey(i), active: i == index, child: children[i]),
      ],
    );
  }
}

class _TabPage extends StatefulWidget {
  const _TabPage({super.key, required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<_TabPage> createState() => _TabPageState();
}

class _TabPageState extends State<_TabPage>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    value: widget.active ? 1 : 0,
  );

  @override
  void didUpdateWidget(_TabPage old) {
    super.didUpdateWidget(old);
    if (widget.active != old.active) {
      widget.active
          ? _c.forward(from: 0)
          : _c.animateBack(0, duration: Motion.fast);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !widget.active,
      child: ExcludeFocus(
        excluding: !widget.active,
        child: TickerMode(
          enabled: widget.active,
          child: AnimatedBuilder(
            animation: _c,
            // Tab switches only fade/move this cached layer.
            child: RepaintBoundary(child: widget.child),
            builder: (context, child) {
              final t = Motion.decelerate.transform(_c.value);
              // Hidden tabs are neither painted nor visible to semantics.
              return Visibility(
                visible: _c.value > 0,
                maintainState: true,
                maintainAnimation: true,
                maintainSize: true,
                child: Opacity(
                  opacity: _c.value,
                  child: Transform(
                    alignment: Alignment.topCenter,
                    transform: Motion.perspective()
                      ..translateByDouble(0, (1 - t) * 24, 0, 1)
                      ..scaleByDouble(0.96 + 0.04 * t, 0.96 + 0.04 * t, 1, 1),
                    child: child,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Floating nav with a pill that glides to the selected tab.
class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, 'Home'),
    (Icons.search_rounded, Icons.search_rounded, 'Search'),
    (Icons.library_music_outlined, Icons.library_music_rounded, 'Library'),
    (Icons.favorite_border_rounded, Icons.favorite_rounded, 'Liked'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final pill = p.isDark ? p.accent : AppColors.ink;
    return Container(
      decoration: BoxDecoration(
        color: p.bg,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Stack(
            children: [
              // Sliding selection pill (each slot is a quarter of the width).
              AnimatedAlign(
                duration: const Duration(milliseconds: 460),
                curve: Curves.easeOutBack,
                alignment: Alignment(
                  -1 + 2 * selected / (_items.length - 1),
                  0,
                ),
                child: FractionallySizedBox(
                  widthFactor: 1 / _items.length,
                  heightFactor: 1,
                  // Wraps both the icon and its label, with even margins.
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      decoration: BoxDecoration(
                        color: pill.withValues(alpha: p.isDark ? 0.16 : 0.08),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          if (p.isDark)
                            BoxShadow(
                              color: p.accent.withValues(alpha: 0.22),
                              blurRadius: 18,
                              spreadRadius: -4,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < _items.length; i++)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: i == selected,
                        label: _items[i].$3,
                        child: Pressable(
                          onTap: () => onSelect(i),
                          scale: 0.85,
                          tilt: 0,
                          child: _NavIcon(
                            selected: i == selected,
                            icon: _items[i].$1,
                            selectedIcon: _items[i].$2,
                            label: _items[i].$3,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.selected,
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final bool selected;
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = selected ? p.accentText : p.muted;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedScale(
          scale: selected ? 1.12 : 1,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutBack,
          child: AnimatedSwitcher(
            duration: Motion.medium,
            transitionBuilder: (child, a) => RotationTransition(
              turns: Tween(begin: -0.1, end: 0.0).animate(a),
              child: FadeTransition(opacity: a, child: child),
            ),
            child: Icon(
              selected ? selectedIcon : icon,
              key: ValueKey(selected),
              size: 24,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        AnimatedDefaultTextStyle(
          duration: Motion.medium,
          style: AppText.ui(
            10,
            weight: selected ? FontWeight.w700 : FontWeight.w500,
            color: color,
            letterSpacing: 0.3,
          ),
          child: Text(label, maxLines: 1),
        ),
      ],
    );
  }
}
