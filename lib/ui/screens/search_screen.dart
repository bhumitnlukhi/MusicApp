import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/catalog.dart';
import '../../data/models.dart';
import '../../data/music_repository.dart';
import '../../state/player_controller.dart';
import '../navigation.dart';
import '../widgets/common.dart';
import '../widgets/track_tile.dart';
import 'discover_screen.dart';

/// Search tab (light): trending + genres when idle, live results when typing.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.focusNode});

  final FocusNode? focusNode;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _query = text.trim());
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ThemedScreen(
      dark: false,
      child: Builder(
        builder: (context) {
          final p = context.palette;
          return Scaffold(
            body: SafeArea(
              bottom: false,
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                behavior: HitTestBehavior.translucent,
                child: CustomScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    SliverToBoxAdapter(
                      child: ScreenHeader(
                        label: '02',
                        title: 'Search',
                        actions: [
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
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: TextField(
                          controller: _controller,
                          focusNode: widget.focusNode,
                          onChanged: _onChanged,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (t) => setState(() => _query = t.trim()),
                          style: AppText.ui(14, color: p.fg),
                          decoration: InputDecoration(
                            hintText: 'Artists, songs, albums...',
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: p.muted,
                              size: 20,
                            ),
                            suffixIcon: _controller.text.isEmpty
                                ? null
                                : IconBtn(
                                    Icons.close_rounded,
                                    size: 18,
                                    tooltip: 'Clear',
                                    onTap: () {
                                      _controller.clear();
                                      setState(() => _query = '');
                                    },
                                  ),
                          ),
                        ),
                      ),
                    ),
                    if (_query.isEmpty)
                      const SliverToBoxAdapter(child: _BrowseContent())
                    else
                      SliverToBoxAdapter(
                        child: _SearchResults(
                          key: ValueKey(_query),
                          query: _query,
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BrowseContent extends StatelessWidget {
  const _BrowseContent();

  @override
  Widget build(BuildContext context) {
    final repo = context.read<MusicRepository>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          'Trending Now',
          onSeeAll: () => context.openMix(Catalog.trending),
        ),
        AsyncView<List<Track>>(
          load: () => repo.mixTracks(Catalog.trending),
          builder: (context, tracks) {
            final top = tracks.take(5).toList();
            return Column(
              children: [
                for (var i = 0; i < top.length; i++)
                  TrackTile(
                    track: top[i],
                    number: (i + 1).toString().padLeft(2, '0'),
                    onTap: () => context.read<PlayerController>().playTracks(
                      tracks,
                      index: i,
                    ),
                  ),
              ],
            );
          },
        ),
        const SectionHeader('Browse by Genre'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.0,
            children: [
              for (final genre in Catalog.genres) _GenreTile(mix: genre),
            ],
          ),
        ),
      ],
    );
  }
}

class _GenreTile extends StatelessWidget {
  const _GenreTile({required this.mix});

  final Mix mix;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.openMix(mix),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColorFiltered(
              colorFilter: const ColorFilter.matrix(_desaturate),
              child: MixCover(mix: mix),
            ),
            const ColoredBox(color: Color(0x99000000)),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  mix.title,
                  style: AppText.ui(
                    15,
                    weight: FontWeight.w600,
                    color: AppColors.paper,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Mostly-greyscale color matrix so genre tiles match the moody design.
  static const _desaturate = <double>[
    0.40, 0.45, 0.10, 0, 0, //
    0.30, 0.55, 0.10, 0, 0, //
    0.30, 0.45, 0.20, 0, 0, //
    0, 0, 0, 1, 0,
  ];
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({super.key, required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<MusicRepository>();
    final p = context.palette;
    return AsyncView<(List<Track>, List<ArtistSummary>, List<AlbumSummary>)>(
      load: () => (
        repo.searchTracks(query, limit: 20),
        repo.searchArtists(query, limit: 8),
        repo.searchAlbums(query, limit: 8),
      ).wait,
      builder: (context, results) {
        final (tracks, artists, albums) = results;
        if (tracks.isEmpty && artists.isEmpty && albums.isEmpty) {
          return MessageView(
            icon: Icons.search_off_rounded,
            title: 'No results for "$query"',
            subtitle: 'Try a different spelling or another song.',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (artists.isNotEmpty) ...[
              const SectionHeader('Artists'),
              SizedBox(
                height: 96,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: artists.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 16),
                  itemBuilder: (_, i) => ArtistCircle(artist: artists[i]),
                ),
              ),
            ],
            if (albums.isNotEmpty) ...[
              const SectionHeader('Albums'),
              SizedBox(
                height: 150,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: albums.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, i) {
                    final album = albums[i];
                    return GestureDetector(
                      onTap: () => context.openAlbum(album.id),
                      child: SizedBox(
                        width: 104,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Artwork(url: album.imageUrl, size: 104),
                            const SizedBox(height: 6),
                            Text(
                              album.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.ui(
                                12,
                                weight: FontWeight.w500,
                                color: p.fg,
                              ),
                            ),
                            Text(
                              '${album.artist} · ${album.year}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.ui(10.5, color: p.muted),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            if (tracks.isNotEmpty) ...[
              const SectionHeader('Songs'),
              for (var i = 0; i < tracks.length; i++)
                TrackTile(
                  track: tracks[i],
                  onTap: () => context.read<PlayerController>().playTracks(
                    tracks,
                    index: i,
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}
