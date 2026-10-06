import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/catalog.dart';
import '../../data/models.dart';
import '../../data/music_repository.dart';
import '../../state/library_controller.dart';
import '../../state/player_controller.dart';
import '../navigation.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';
import '../widgets/track_tile.dart';

/// Home tab (dark): filter chips, a 3D carousel of featured mixes, recently
/// played, mixes and popular artists — over a soft glow in the song's colors.
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key, required this.onOpenSearch});

  final VoidCallback onOpenSearch;

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  static final _filters = ['All', ...Catalog.discoverFilters.keys];
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    final playing = context.select<PlayerController, bool>((c) => c.isPlaying);
    return ThemedScreen(
      dark: true,
      child: Scaffold(
        body: Stack(
          children: [
            // Ambient mood glow behind the header.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 440,
              child: MoodBackdrop(intensity: 0.6, animate: playing),
            ),
            SafeArea(
              bottom: false,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: ScreenHeader(
                      label: '01',
                      title: 'Discover',
                      actions: [
                        IconBtn(
                          Icons.search_rounded,
                          tooltip: 'Search',
                          onTap: widget.onOpenSearch,
                        ),
                        IconBtn(
                          Icons.notifications_none_rounded,
                          tooltip: 'Notifications',
                          onTap: () =>
                              showSnack(context, 'No new notifications'),
                        ),
                      ],
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: PillTabs(
                      tabs: _filters,
                      selected: _filter,
                      onChanged: (i) => setState(() => _filter = i),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: AnimatedSwitcher(
                      duration: Motion.slow,
                      switchInCurve: Motion.decelerate,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, a) => FadeTransition(
                        opacity: a,
                        child: SlideTransition(
                          position: Tween(
                            begin: const Offset(0, 0.04),
                            end: Offset.zero,
                          ).animate(a),
                          child: child,
                        ),
                      ),
                      layoutBuilder: (current, previous) => Stack(
                        alignment: Alignment.topCenter,
                        children: [...previous, ?current],
                      ),
                      child: _filter == 0
                          ? const _AllContent(key: ValueKey('all'))
                          : _FilteredTracks(
                              key: ValueKey(_filter),
                              mix: Catalog.discoverFilters[_filters[_filter]]!,
                            ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AllContent extends StatelessWidget {
  const _AllContent({super.key});

  @override
  Widget build(BuildContext context) {
    final recent = context.select<LibraryController, List<Track>>(
      (l) => l.recent,
    );
    var section = 0;
    Widget enter(Widget child) => Entrance(index: section++, child: child);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        enter(
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: _FeaturedCarousel(
              mixes: [Catalog.heroMix, ...Catalog.madeForYou],
            ),
          ),
        ),
        if (recent.isNotEmpty) ...[
          enter(const SectionHeader('Recently Played')),
          enter(
            _CardRow(
              itemCount: recent.length,
              itemBuilder: (context, i) => _SquareCard(
                imageUrl: recent[i].imageUrl,
                title: recent[i].title,
                caption: recent[i].artist,
                onTap: () => context.read<PlayerController>().playTracks(
                  recent,
                  index: i,
                ),
              ),
            ),
          ),
        ],
        enter(SectionHeader(recent.isEmpty ? 'Made For You' : 'Your Mixes')),
        enter(
          _CardRow(
            itemCount: Catalog.madeForYou.length,
            itemBuilder: (context, i) {
              final mix = Catalog.madeForYou[i];
              return _SquareCard(
                imageUrl: null,
                mix: mix,
                title: mix.title,
                caption: 'Playlist',
                onTap: () => context.openMix(mix),
              );
            },
          ),
        ),
        enter(const SectionHeader('Popular Artists')),
        enter(const _PopularArtists()),
      ],
    );
  }
}

/// Horizontal row of [_SquareCard]s, tall enough for large fonts.
class _CardRow extends StatelessWidget {
  const _CardRow({required this.itemCount, required this.itemBuilder});

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: _SquareCard.size + 56,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      clipBehavior: Clip.none,
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(width: 14),
      itemBuilder: itemBuilder,
    ),
  );
}

/// Featured mixes as a cover-flow: the centered card faces you, the cards on
/// either side turn away in 3D. Auto-advances until you touch it.
class _FeaturedCarousel extends StatefulWidget {
  const _FeaturedCarousel({required this.mixes});

  final List<Mix> mixes;

  @override
  State<_FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends State<_FeaturedCarousel> {
  final _controller = PageController(viewportFraction: 0.86);
  Timer? _auto;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _restartAuto();
  }

  void _restartAuto() {
    _auto?.cancel();
    _auto = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!_controller.hasClients ||
          !TickerMode.getValuesNotifier(context).value.enabled) {
        return;
      }
      _controller.animateToPage(
        (_page + 1) % widget.mixes.length,
        duration: const Duration(milliseconds: 900),
        curve: Motion.emphasized,
      );
    });
  }

  @override
  void dispose() {
    _auto?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxWidth * 0.86 / 1.75;
        return Column(
          children: [
            SizedBox(
              height: height,
              child: NotificationListener<ScrollStartNotification>(
                onNotification: (n) {
                  if (n.dragDetails != null) _restartAuto();
                  return false;
                },
                child: PageView.builder(
                  controller: _controller,
                  clipBehavior: Clip.none,
                  itemCount: widget.mixes.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (context, i) => AnimatedBuilder(
                    animation: _controller,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: _HeroMixCard(mix: widget.mixes[i], index: i),
                    ),
                    builder: (context, child) {
                      final page =
                          _controller.hasClients &&
                              _controller.position.haveDimensions
                          ? _controller.page!
                          : _page.toDouble();
                      final delta = (i - page).clamp(-1.5, 1.5);
                      final s = 1 - delta.abs() * 0.1;
                      return Transform(
                        alignment: delta > 0
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        transform: Motion.perspective()
                          ..rotateY(-delta * 0.55)
                          ..scaleByDouble(s, s, 1, 1),
                        child: Opacity(
                          opacity: (1 - delta.abs() * 0.35).clamp(0.0, 1.0),
                          // Cached card: swiping only moves the layer.
                          child: RepaintBoundary(child: child),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Page dots: the current one stretches into a pill.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < widget.mixes.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _page ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _page
                          ? p.accent
                          : p.fg.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Banner with the mix's first cover as background.
class _HeroMixCard extends StatelessWidget {
  const _HeroMixCard({required this.mix, required this.index});

  final Mix mix;
  final int index;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<MusicRepository>();
    final p = context.palette;
    return Pressable(
      onTap: () => context.openMix(mix),
      scale: 0.97,
      tilt: 0.08,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              MixCover(mix: mix),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color.lerp(
                        Colors.black,
                        p.accentDeep,
                        0.5,
                      )!.withValues(alpha: 0.95),
                      Colors.black.withValues(alpha: 0.65),
                      Colors.black.withValues(alpha: 0.15),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 72, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ScreenLabel(
                      (index + 1).toString().padLeft(2, '0'),
                      color: p.accent,
                    ),
                    const SizedBox(height: 6),
                    Flexible(
                      flex: 3,
                      child: DisplayTitle(
                        mix.title,
                        size: 34,
                        color: AppColors.paper,
                        maxLines: 2,
                      ),
                    ),
                    const Spacer(),
                    if (mix.subtitle.isNotEmpty)
                      Text(
                        mix.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.ui(
                          11.5,
                          color: AppColors.paper.withValues(alpha: 0.85),
                          height: 1.35,
                        ),
                      ),
                  ],
                ),
              ),
              Positioned(
                right: 14,
                bottom: 14,
                child: RoundPlayButton(
                  style: PlayButtonStyle.lime,
                  size: 46,
                  onTap: () async {
                    final player = context.read<PlayerController>();
                    try {
                      player.playTracks(await repo.mixTracks(mix));
                    } catch (_) {
                      if (context.mounted) {
                        showSnack(context, "Couldn't load ${mix.title}");
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cover for a [Mix]: the artwork of its first track.
class MixCover extends StatefulWidget {
  const MixCover({super.key, required this.mix, this.size});

  final Mix mix;
  final double? size;

  @override
  State<MixCover> createState() => _MixCoverState();
}

class _MixCoverState extends State<MixCover> {
  late Future<List<Track>> _tracks = _load();

  Future<List<Track>> _load() =>
      context.read<MusicRepository>().mixTracks(widget.mix);

  @override
  void didUpdateWidget(MixCover old) {
    super.didUpdateWidget(old);
    if (old.mix.id != widget.mix.id) _tracks = _load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Track>>(
      future: _tracks,
      builder: (context, snap) => Artwork(
        url: snap.data?.firstOrNull?.imageUrl ?? '',
        size: widget.size,
        radius: 0,
        icon: Icons.queue_music_rounded,
      ),
    );
  }
}

class _SquareCard extends StatelessWidget {
  const _SquareCard({
    required this.imageUrl,
    required this.title,
    required this.caption,
    required this.onTap,
    this.mix,
  });

  final String? imageUrl;
  final Mix? mix;
  final String title;
  final String caption;
  final VoidCallback onTap;

  static const size = 124.0;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Pressable(
      onTap: onTap,
      child: SizedBox(
        width: size,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: mix != null
                    ? MixCover(mix: mix!, size: size)
                    : Artwork(url: imageUrl!, size: size, radius: 0),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.ui(12.5, weight: FontWeight.w600, color: p.fg),
            ),
            Text(
              caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.ui(11, color: p.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _PopularArtists extends StatelessWidget {
  const _PopularArtists();

  @override
  Widget build(BuildContext context) {
    final repo = context.read<MusicRepository>();
    return AsyncView<List<ArtistSummary>>(
      load: () async {
        final found = await Future.wait(
          Catalog.popularArtists.map((name) async {
            try {
              return await repo.findArtist(name);
            } catch (_) {
              return null;
            }
          }),
        );
        return found.whereType<ArtistSummary>().toList();
      },
      loading: const LoadingView(height: ArtistCircle.rowHeight),
      builder: (context, artists) => SizedBox(
        height: ArtistCircle.rowHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: artists.length,
          separatorBuilder: (_, _) => const SizedBox(width: 14),
          itemBuilder: (context, i) => Entrance(
            index: i,
            child: ArtistCircle(artist: artists[i]),
          ),
        ),
      ),
    );
  }
}

/// Round artist photo inside a ring in the song's colors.
class ArtistCircle extends StatelessWidget {
  const ArtistCircle({super.key, required this.artist, this.size = 64});

  final ArtistSummary artist;
  final double size;

  /// Height of a horizontal row of default-size circles (room for large
  /// fonts).
  static const rowHeight = 112.0;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Pressable(
      onTap: () => context.openArtist(artist.id),
      scale: 0.9,
      child: SizedBox(
        width: size + 12,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 900),
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: p.isDark
                      ? [p.accent, p.glow, p.accent]
                      : [AppColors.ink, p.muted, AppColors.ink],
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(color: p.bg, shape: BoxShape.circle),
                child: Artwork(
                  url: artist.imageUrl,
                  size: size,
                  circle: true,
                  icon: Icons.person_rounded,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              artist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppText.ui(11, weight: FontWeight.w500, color: p.fg),
            ),
          ],
        ),
      ),
    );
  }
}

/// Track list for a Discover filter chip.
class _FilteredTracks extends StatelessWidget {
  const _FilteredTracks({super.key, required this.mix});

  final Mix mix;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<MusicRepository>();
    return AsyncView<List<Track>>(
      load: () => repo.mixTracks(mix),
      builder: (context, tracks) {
        final player = context.read<PlayerController>();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${tracks.length} songs',
                      style: AppText.ui(12, color: context.palette.muted),
                    ),
                  ),
                  IconBtn(
                    Icons.shuffle_rounded,
                    tooltip: 'Shuffle',
                    onTap: () => player.shufflePlay(tracks),
                  ),
                  const SizedBox(width: 4),
                  RoundPlayButton(
                    style: PlayButtonStyle.lime,
                    size: 42,
                    onTap: () => player.playTracks(tracks),
                  ),
                ],
              ),
            ),
            for (var i = 0; i < tracks.length; i++)
              Entrance(
                index: i,
                child: TrackTile(
                  track: tracks[i],
                  onTap: () => player.playTracks(tracks, index: i),
                ),
              ),
          ],
        );
      },
    );
  }
}
