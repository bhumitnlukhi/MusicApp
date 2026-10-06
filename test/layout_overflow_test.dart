import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:music_app/data/lyrics_repository.dart';
import 'package:music_app/data/models.dart';
import 'package:music_app/data/music_repository.dart';
import 'package:music_app/data/catalog.dart';
import 'package:music_app/main.dart';
import 'package:music_app/state/accent_controller.dart';
import 'package:music_app/state/library_controller.dart';
import 'package:music_app/state/player_controller.dart';
import 'package:music_app/ui/navigation.dart';
import 'package:music_app/ui/screens/artist_screen.dart';
import 'package:music_app/ui/screens/home_shell.dart';
import 'package:music_app/ui/screens/library_screen.dart';
import 'package:music_app/ui/screens/now_playing_screen.dart';
import 'package:music_app/ui/widgets/mini_player.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Renders every screen at small / large / landscape sizes and with a huge
/// font scale; any RenderFlex overflow or other layout error fails the test.

const _long =
    'An Extremely Long Song Title That Keeps Going (Deluxe Remastered Edition)';

Track _track(int i) => Track(
  id: 't$i',
  title: i.isEven ? _long : 'Song $i',
  artist: 'Some Artist, Another Featured Artist, And One More',
  album: 'Album With A Very Very Long Name $i',
  albumId: 'a$i',
  imageUrl: '',
  streamUrl: 'https://example.com/$i.mp3',
  duration: const Duration(minutes: 3, seconds: 21),
  artistId: 'ar1',
  playCount: 1234567,
);

final _tracks = [for (var i = 0; i < 12; i++) _track(i)];

const _artist = ArtistSummary(
  id: 'ar1',
  name: 'An Artist With A Remarkably Long Stage Name',
  imageUrl: '',
);

const _album = AlbumSummary(
  id: 'a1',
  title: 'A Long Album Title For Testing Purposes',
  artist: 'Some Artist',
  year: '2024',
  imageUrl: '',
);

class _FakeRepo implements MusicRepository {
  @override
  Future<List<Track>> searchTracks(String query, {int limit = 20}) async =>
      _tracks.take(limit).toList();

  @override
  Future<List<ArtistSummary>> searchArtists(
    String query, {
    int limit = 10,
  }) async => [_artist];

  @override
  Future<List<AlbumSummary>> searchAlbums(
    String query, {
    int limit = 10,
  }) async => [_album];

  @override
  Future<ArtistSummary?> findArtist(String name) async => _artist;

  @override
  Future<ArtistDetails> artist(String id) async => ArtistDetails(
    summary: _artist,
    topTracks: _tracks,
    albums: const [_album, _album],
    followers: 98765432,
    language: 'english',
    bio: 'A long biography. ' * 20,
  );

  @override
  Future<AlbumDetails> album(String id) async =>
      AlbumDetails(summary: _album, tracks: _tracks);
}

class _FakeLyrics implements LyricsRepository {
  @override
  Future<Lyrics?> fetch(Track track) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePlayer extends ChangeNotifier implements PlayerController {
  @override
  final queue = _tracks;
  @override
  int? currentIndex = 0;
  @override
  Track? get current => queue[currentIndex!];
  @override
  List<Track> get upNext => queue.sublist(currentIndex! + 1);
  @override
  bool isPlaying = true;
  @override
  bool get isBuffering => false;
  @override
  bool get shuffleEnabled => true;
  @override
  LoopMode get loopMode => LoopMode.all;
  @override
  Stream<Duration> get positionStream =>
      Stream.value(const Duration(minutes: 1));
  @override
  Duration get position => const Duration(minutes: 1);
  @override
  Duration get duration => const Duration(minutes: 3, seconds: 21);
  @override
  Stream<String> get errors => const Stream.empty();
  @override
  void togglePlay() {
    isPlaying = !isPlaying;
    notifyListeners();
  }

  @override
  void next() {
    currentIndex = currentIndex! + 1;
    notifyListeners();
  }

  @override
  void previous() {}
  @override
  void seek(Duration position) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required Size size,
  double textScale = 1,
  bool onboarding = false,
}) async {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = size * 3;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);

  SharedPreferences.setMockInitialValues({});
  final library = await LibraryController.load();
  for (final t in _tracks.take(5)) {
    library.addRecent(t);
    library.toggleLike(t);
  }
  final player = _FakePlayer();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<MusicRepository>(create: (_) => _FakeRepo()),
        Provider<LyricsRepository>(create: (_) => _FakeLyrics()),
        ChangeNotifierProvider.value(value: library),
        ChangeNotifierProvider<PlayerController>.value(value: player),
        ChangeNotifierProvider(
          create: (context) =>
              AccentController(context.read<PlayerController>()),
        ),
      ],
      child: MusicApp(showOnboarding: onboarding),
    ),
  );
  await _settle(tester);
}

/// Lets entrances and transitions finish (looping animations never settle).
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder.first, warnIfMissed: false);
  await _settle(tester);
}

/// Bottom nav labels come after the page content in the tree.
Future<void> _tapNav(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last, warnIfMissed: false);
  await _settle(tester);
}

Future<void> _back(WidgetTester tester) async {
  final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
  nav.pop();
  await _settle(tester);
}

Future<void> _tearDown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 10));
}

const _sizes = {
  'small phone': Size(320, 568),
  'large phone': Size(412, 915),
  'landscape': Size(800, 360),
};

void main() {
  for (final MapEntry(key: name, value: size) in _sizes.entries) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('no overflow on $name at ${scale}x text', (tester) async {
        await _pumpApp(tester, size: size, textScale: scale);

        // Tabs.
        for (final tab in ['Search', 'Library', 'Liked', 'Home']) {
          await _tapNav(tester, tab);
        }

        // Library sub-tabs.
        await _tapNav(tester, 'Library');
        final pills = find
            .descendant(
              of: find.byType(LibraryScreen),
              matching: find.byType(Scrollable),
            )
            .first;
        for (final sub in ['Artists', 'Albums', 'Liked', 'Playlists']) {
          final pill = find.descendant(
            of: find.byType(LibraryScreen),
            matching: find.text(sub),
          );
          // 'Playlists' is the first pill: scroll back to the start for it.
          await tester.scrollUntilVisible(
            pill,
            sub == 'Playlists' ? -80 : 80,
            scrollable: pills,
          );
          await _tap(tester, pill);
        }
        await _tapNav(tester, 'Home');

        BuildContext shell() => tester.element(find.byType(HomeShell));

        // A mix (collection screen), then back.
        unawaited(shell().openMix(Catalog.madeForYou.first));
        await _settle(tester);
        await _back(tester);

        // An album.
        unawaited(shell().openAlbum('a1'));
        await _settle(tester);
        await _back(tester);

        // Artist page, both tabs.
        unawaited(shell().openArtist('ar1'));
        await _settle(tester);
        await tester.scrollUntilVisible(
          find.text('About'),
          120,
          scrollable: find
              .descendant(
                of: find.byType(ArtistScreen),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await _tap(tester, find.text('About'));
        await _back(tester);

        // Now Playing → Queue / Lyrics.
        await _tap(
          tester,
          find.descendant(
            of: find.byType(MiniPlayer),
            matching: find.text(_tracks.first.title),
          ),
        );
        BuildContext nowPlaying() =>
            tester.element(find.byType(NowPlayingScreen));
        unawaited(nowPlaying().openQueue());
        await _settle(tester);
        await _back(tester);
        unawaited(nowPlaying().openLyrics());
        await _settle(tester);
        await _back(tester);
        await _back(tester);

        await _tearDown(tester);
      });
    }

    testWidgets('onboarding fits on $name', (tester) async {
      await _pumpApp(tester, size: size, textScale: 2, onboarding: true);
      await _tearDown(tester);
    });
  }
}
