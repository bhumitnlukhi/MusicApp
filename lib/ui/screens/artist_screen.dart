import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models.dart';
import '../../data/music_repository.dart';
import '../../state/library_controller.dart';
import '../../state/player_controller.dart';
import '../navigation.dart';
import '../widgets/common.dart';
import '../widgets/mini_player.dart';
import '../widgets/track_tile.dart';

/// Artist page (dark): big photo header, follow/play, popular songs, albums.
class ArtistScreen extends StatelessWidget {
  const ArtistScreen({super.key, required this.artistId});

  final String artistId;

  @override
  Widget build(BuildContext context) {
    return ThemedScreen(
      dark: true,
      child: Scaffold(
        bottomNavigationBar: const SafeArea(top: false, child: MiniPlayer()),
        body: AsyncView<ArtistDetails>(
          load: () => context.read<MusicRepository>().artist(artistId),
          loading: const SafeArea(child: LoadingView(height: 300)),
          builder: (_, artist) => _ArtistBody(artist: artist),
        ),
      ),
    );
  }
}

class _ArtistBody extends StatefulWidget {
  const _ArtistBody({required this.artist});

  final ArtistDetails artist;

  @override
  State<_ArtistBody> createState() => _ArtistBodyState();
}

class _ArtistBodyState extends State<_ArtistBody> {
  static const _tabs = ['Music', 'About'];
  int _tab = 0;
  bool _showAllSongs = false;

  @override
  Widget build(BuildContext context) {
    final artist = widget.artist;
    final p = context.palette;
    final player = context.watch<PlayerController>();
    final library = context.watch<LibraryController>();
    final following = library.isFollowing(artist.summary.id);
    final topTracks = artist.topTracks;
    final shown = _showAllSongs ? topTracks : topTracks.take(5).toList();
    final topPadding = MediaQuery.paddingOf(context).top;

    final current = player.current;
    final playingThis =
        current != null &&
        topTracks.any((t) => t.id == current.id) &&
        player.isPlaying;

    return CustomScrollView(
      slivers: [
        // ---- photo header ----
        SliverToBoxAdapter(
          child: SizedBox(
            height: 320 + topPadding,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColorFiltered(
                  colorFilter: const ColorFilter.matrix(_greyscale),
                  child: Artwork(
                    url: artist.summary.imageUrl,
                    radius: 0,
                    icon: Icons.person_rounded,
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0, 0.35, 1],
                      colors: [
                        Color(0x88000000),
                        Color(0x00000000),
                        AppColors.ink,
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: topPadding,
                  left: 4,
                  right: 8,
                  child: Row(
                    children: [
                      IconBtn(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        tooltip: 'Back',
                        onTap: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        artist.summary.name,
                        style: AppText.ui(
                          28,
                          weight: FontWeight.w700,
                          color: p.fg,
                        ),
                      ),
                      if (artist.followers != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${formatCount(artist.followers!)} followers',
                          style: AppText.ui(12, color: p.muted),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // ---- actions ----
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Row(
              children: [
                OutlinedButton(
                  onPressed: () => library.toggleFollow(artist.summary),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: p.fg,
                    side: BorderSide(color: following ? p.accent : p.muted),
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: Text(
                    following ? 'Following' : 'Follow',
                    style: AppText.ui(
                      12.5,
                      weight: FontWeight.w500,
                      color: following ? p.accent : p.fg,
                    ),
                  ),
                ),
                const Spacer(),
                if (topTracks.isNotEmpty) ...[
                  IconBtn(
                    Icons.shuffle_rounded,
                    tooltip: 'Shuffle',
                    onTap: () => player.shufflePlay(topTracks),
                  ),
                  const SizedBox(width: 8),
                  RoundPlayButton(
                    style: PlayButtonStyle.lime,
                    size: 50,
                    playing: playingThis,
                    onTap: () {
                      if (current != null &&
                          topTracks.any((t) => t.id == current.id)) {
                        player.togglePlay();
                      } else {
                        player.playTracks(topTracks);
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        ),

        // ---- tabs ----
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: p.border)),
              ),
              child: Row(
                children: [
                  for (var i = 0; i < _tabs.length; i++)
                    GestureDetector(
                      onTap: () => setState(() => _tab = i),
                      child: Container(
                        margin: const EdgeInsets.only(right: 28),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: i == _tab ? p.accent : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                        child: Text(
                          _tabs[i],
                          style: AppText.ui(
                            12.5,
                            weight: i == _tab
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: i == _tab ? p.accent : p.muted,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        if (_tab == 0) ...[
          if (topTracks.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: SectionHeader(
                'Popular',
                onSeeAll: topTracks.length > 5
                    ? () => setState(() => _showAllSongs = !_showAllSongs)
                    : null,
              ),
            ),
            SliverList.builder(
              itemCount: shown.length,
              itemBuilder: (context, i) {
                final t = shown[i];
                return TrackTile(
                  track: t,
                  number: '${i + 1}',
                  subtitle: t.playCount != null
                      ? '${formatCount(t.playCount!)} plays'
                      : t.album,
                  onTap: () => player.playTracks(topTracks, index: i),
                );
              },
            ),
          ],
          if (artist.albums.isNotEmpty) ...[
            const SliverToBoxAdapter(child: SectionHeader('Albums')),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 160,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: artist.albums.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, i) {
                    final album = artist.albums[i];
                    return GestureDetector(
                      onTap: () => context.openAlbum(album.id),
                      child: SizedBox(
                        width: 112,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Artwork(url: album.imageUrl, size: 112),
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
                              album.year,
                              style: AppText.ui(10.5, color: p.muted),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ] else
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (artist.followers != null)
                    _Fact('Followers', formatCount(artist.followers!)),
                  if (artist.language != null && artist.language!.isNotEmpty)
                    _Fact('Language', _capitalize(artist.language!)),
                  _Fact('Top songs', '${topTracks.length}'),
                  const SizedBox(height: 12),
                  Text(
                    artist.bio ?? 'No biography available for this artist yet.',
                    style: AppText.ui(13, color: p.muted, height: 1.6),
                  ),
                ],
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  static const _greyscale = <double>[
    0.30, 0.59, 0.11, 0, 0, //
    0.30, 0.59, 0.11, 0, 0, //
    0.30, 0.59, 0.11, 0, 0, //
    0, 0, 0, 1, 0,
  ];
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: AppText.ui(12.5, color: p.muted)),
          ),
          Text(
            value,
            style: AppText.ui(13, weight: FontWeight.w600, color: p.fg),
          ),
        ],
      ),
    );
  }
}
