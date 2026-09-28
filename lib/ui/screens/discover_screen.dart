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
import '../widgets/track_tile.dart';

/// Home tab (dark): filter chips, hero mix, recently played, popular artists.
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
    return ThemedScreen(
      dark: true,
      child: Scaffold(
        body: SafeArea(
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
                      onTap: () => showSnack(context, 'No new notifications'),
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
              if (_filter == 0)
                const SliverToBoxAdapter(child: _AllContent())
              else
                _FilteredTracks(
                  key: ValueKey(_filter),
                  mix: Catalog.discoverFilters[_filters[_filter]]!,
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AllContent extends StatelessWidget {
  const _AllContent();

  @override
  Widget build(BuildContext context) {
    final recent = context.select<LibraryController, List<Track>>(
      (l) => l.recent,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: _HeroMixCard(mix: Catalog.heroMix),
        ),
        if (recent.isNotEmpty) ...[
          const SectionHeader('Recently Played'),
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: recent.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
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
        SectionHeader(recent.isEmpty ? 'Made For You' : 'Your Mixes'),
        SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: Catalog.madeForYou.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
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
        const SectionHeader('Popular Artists'),
        const _PopularArtists(),
      ],
    );
  }
}

/// "TODAY'S VIBES" banner with the mix's first cover as background.
class _HeroMixCard extends StatelessWidget {
  const _HeroMixCard({required this.mix});

  final Mix mix;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<MusicRepository>();
    return GestureDetector(
      onTap: () => context.openMix(mix),
      child: AspectRatio(
        aspectRatio: 1.9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            fit: StackFit.expand,
            children: [
              MixCover(mix: mix),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xF2000000),
                      Color(0xB3000000),
                      Color(0x4D000000),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ScreenLabel('03', color: AppColors.paper),
                    const SizedBox(height: 6),
                    DisplayTitle(mix.title, size: 34, color: AppColors.paper),
                    const Spacer(),
                    Text(
                      mix.subtitle,
                      style: AppText.ui(
                        11.5,
                        color: AppColors.paper,
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
                  style: PlayButtonStyle.paper,
                  size: 40,
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
class MixCover extends StatelessWidget {
  const MixCover({super.key, required this.mix, this.size});

  final Mix mix;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<MusicRepository>();
    return FutureBuilder<List<Track>>(
      future: repo.mixTracks(mix),
      builder: (context, snap) => Artwork(
        url: snap.data?.firstOrNull?.imageUrl ?? '',
        size: size,
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

  static const _size = 88.0;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: _size,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: mix != null
                  ? MixCover(mix: mix!, size: _size)
                  : Artwork(url: imageUrl!, size: _size, radius: 0),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.ui(12, weight: FontWeight.w500, color: p.fg),
            ),
            Text(
              caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.ui(10.5, color: p.muted),
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
      loading: const LoadingView(height: 96),
      builder: (context, artists) => SizedBox(
        height: 96,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: artists.length,
          separatorBuilder: (_, _) => const SizedBox(width: 16),
          itemBuilder: (context, i) => ArtistCircle(artist: artists[i]),
        ),
      ),
    );
  }
}

class ArtistCircle extends StatelessWidget {
  const ArtistCircle({super.key, required this.artist, this.size = 60});

  final ArtistSummary artist;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GestureDetector(
      onTap: () => context.openArtist(artist.id),
      child: SizedBox(
        width: size + 8,
        child: Column(
          children: [
            Artwork(
              url: artist.imageUrl,
              size: size,
              circle: true,
              icon: Icons.person_rounded,
            ),
            const SizedBox(height: 8),
            Text(
              artist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppText.ui(10.5, color: p.fg),
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
    return SliverToBoxAdapter(
      child: AsyncView<List<Track>>(
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
                      size: 40,
                      onTap: () => player.playTracks(tracks),
                    ),
                  ],
                ),
              ),
              for (var i = 0; i < tracks.length; i++)
                TrackTile(
                  track: tracks[i],
                  onTap: () => player.playTracks(tracks, index: i),
                ),
            ],
          );
        },
      ),
    );
  }
}
