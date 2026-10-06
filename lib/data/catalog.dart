import 'models.dart';
import 'music_repository.dart';

/// Hand-picked content for the home and search screens. Edit freely — each
/// mix is just a list of search queries.
class Catalog {
  Catalog._();

  static const heroMix = Mix(
    id: 'todays-vibes',
    title: "Today's Vibes",
    subtitle: 'Chill tracks for\na better day',
    queries: ['weekend chill', 'acoustic chill', 'prateek kuhad'],
  );

  static const madeForYou = [
    Mix(
      id: 'midnight',
      title: 'Midnight',
      subtitle: 'After-dark drives &\nslow-burn R&B',
      queries: ['late night drive', 'the weeknd', 'anuv jain'],
    ),
    Mix(
      id: 'focus',
      title: 'Focus Mode',
      subtitle: 'Lo-fi beats to lock in\nand get things done',
      queries: ['lofi focus', 'lofi study'],
    ),
    Mix(
      id: 'chill',
      title: 'Chill Mix',
      subtitle: 'Easy acoustic grooves\nfor slow mornings',
      queries: ['weekend chill', 'acoustic chill', 'coldplay'],
    ),
    Mix(
      id: 'workout',
      title: 'Workout',
      subtitle: 'High-energy anthems\nto push harder',
      queries: ['imagine dragons', 'eminem', 'party hits'],
    ),
    Mix(
      id: 'romance',
      title: 'Romance',
      subtitle: 'Love songs for\nevery heartbeat',
      queries: ['hindi romantic', 'arijit singh', 'bollywood hits'],
    ),
  ];

  static const popularArtists = [
    'Billie Eilish',
    'The Weeknd',
    'Arijit Singh',
    'Taylor Swift',
    'Diljit Dosanjh',
    'Drake',
  ];

  /// Discover filter chips (other than "All").
  static const discoverFilters = {
    'For You': Mix(
      id: 'for-you',
      title: 'For You',
      queries: ['arijit singh', 'the weeknd', 'taylor swift', 'diljit dosanjh'],
    ),
    'Mood': Mix(
      id: 'mood',
      title: 'Mood',
      queries: ['weekend chill', 'hindi romantic', 'acoustic chill'],
    ),
    'New Releases': Mix(
      id: 'new-releases',
      title: 'New Releases',
      queries: ['latest hindi songs', 'latest punjabi songs'],
    ),
    'Charts': Mix(
      id: 'charts',
      title: 'Charts',
      queries: ['bollywood hits', 'drake', 'punjabi hits', 'taylor swift'],
    ),
  };

  static const trending = Mix(
    id: 'trending',
    title: 'Trending Now',
    queries: ['latest hindi songs', 'bollywood hits', 'punjabi hits'],
  );

  static const genres = [
    Mix(
      id: 'pop',
      title: 'Pop',
      queries: ['taylor swift', 'billie eilish', 'ed sheeran', 'the weeknd'],
    ),
    Mix(
      id: 'hiphop',
      title: 'Hip Hop',
      queries: ['drake', 'eminem', 'kendrick lamar', 'divine'],
    ),
    Mix(
      id: 'rock',
      title: 'Rock',
      queries: ['linkin park', 'imagine dragons', 'rock classics', 'coldplay'],
    ),
    Mix(id: 'lofi', title: 'Lo-Fi', queries: ['lofi focus', 'lofi study']),
    Mix(
      id: 'punjabi',
      title: 'Punjabi',
      queries: ['punjabi hits', 'diljit dosanjh'],
    ),
    Mix(
      id: 'indie',
      title: 'Indie',
      queries: ['prateek kuhad', 'anuv jain', 'tame impala'],
    ),
  ];
}

extension MixLoading on MusicRepository {
  /// Runs each of the mix's queries, then interleaves the results
  /// (a1, b1, c1, a2, b2…) and drops duplicate songs.
  Future<List<Track>> mixTracks(Mix mix, {int total = 24}) async {
    final perQuery = (total / mix.queries.length).ceil() + 4;
    final results = await Future.wait(
      mix.queries.map((q) async {
        try {
          return await searchTracks(q, limit: perQuery);
        } catch (_) {
          return null;
        }
      }),
    );
    if (results.every((r) => r == null)) {
      throw Exception("Couldn't load ${mix.title}");
    }

    final lists = results.whereType<List<Track>>().toList();
    final seen = <String>{};
    final mixed = <Track>[];
    final longest = lists.fold(0, (m, l) => l.length > m ? l.length : m);
    for (var i = 0; i < longest && mixed.length < total; i++) {
      for (final list in lists) {
        if (i >= list.length) continue;
        final t = list[i];
        final key = '${t.title.toLowerCase()}|${t.artist.split(',').first}';
        if (seen.add(key)) mixed.add(t);
        if (mixed.length >= total) break;
      }
    }
    return mixed;
  }
}
