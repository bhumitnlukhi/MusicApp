import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../state/player_controller.dart';
import '../widgets/common.dart';
import '../widgets/mini_player.dart';
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
        body: IndexedStack(
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
    return Container(
      decoration: BoxDecoration(
        color: p.bg,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == selected,
                    label: _items[i].$3,
                    child: InkWell(
                      onTap: () => onSelect(i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            i == selected ? _items[i].$2 : _items[i].$1,
                            size: 24,
                            color: i == selected ? p.accentText : p.fg,
                          ),
                          const SizedBox(height: 6),
                          // Light screens mark the tab with an underline,
                          // since lime doesn't read on paper.
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: i == selected && !p.isDark ? 18 : 0,
                            height: 2,
                            color: p.fg,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
