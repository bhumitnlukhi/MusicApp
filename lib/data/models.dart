/// Plain app models. The UI only ever sees these — never the raw API types —
/// so the data source can be swapped (JioSaavn, Jamendo, Audius…) without
/// touching any screen.
library;

class Track {
  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.albumId,
    required this.imageUrl,
    required this.streamUrl,
    required this.duration,
    this.artistId,
    this.playCount,
  });

  final String id;
  final String title;
  final String artist;
  final String album;
  final String albumId;
  final String imageUrl;
  final String streamUrl;
  final Duration duration;

  /// First primary artist's id, used for "Go to artist".
  final String? artistId;
  final int? playCount;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'album': album,
    'albumId': albumId,
    'imageUrl': imageUrl,
    'streamUrl': streamUrl,
    'duration': duration.inSeconds,
    'artistId': artistId,
    'playCount': playCount,
  };

  factory Track.fromJson(Map<String, dynamic> json) => Track(
    id: json['id'] as String,
    title: json['title'] as String,
    artist: json['artist'] as String,
    album: json['album'] as String,
    albumId: json['albumId'] as String,
    imageUrl: json['imageUrl'] as String,
    streamUrl: json['streamUrl'] as String,
    duration: Duration(seconds: json['duration'] as int),
    artistId: json['artistId'] as String?,
    playCount: json['playCount'] as int?,
  );
}

class ArtistSummary {
  const ArtistSummary({
    required this.id,
    required this.name,
    required this.imageUrl,
  });

  final String id;
  final String name;
  final String imageUrl;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'imageUrl': imageUrl,
  };

  factory ArtistSummary.fromJson(Map<String, dynamic> json) => ArtistSummary(
    id: json['id'] as String,
    name: json['name'] as String,
    imageUrl: json['imageUrl'] as String,
  );
}

class ArtistDetails {
  const ArtistDetails({
    required this.summary,
    required this.topTracks,
    required this.albums,
    this.followers,
    this.bio,
    this.language,
  });

  final ArtistSummary summary;
  final List<Track> topTracks;
  final List<AlbumSummary> albums;
  final int? followers;
  final String? bio;
  final String? language;
}

class AlbumSummary {
  const AlbumSummary({
    required this.id,
    required this.title,
    required this.artist,
    required this.year,
    required this.imageUrl,
  });

  final String id;
  final String title;
  final String artist;
  final String year;
  final String imageUrl;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'year': year,
    'imageUrl': imageUrl,
  };

  factory AlbumSummary.fromJson(Map<String, dynamic> json) => AlbumSummary(
    id: json['id'] as String,
    title: json['title'] as String,
    artist: json['artist'] as String,
    year: json['year'] as String,
    imageUrl: json['imageUrl'] as String,
  );
}

class AlbumDetails {
  const AlbumDetails({required this.summary, required this.tracks});

  final AlbumSummary summary;
  final List<Track> tracks;
}

/// A curated playlist built from a few search queries whose results are
/// interleaved. JioSaavn's playlist endpoint isn't exposed by the package,
/// and its search mostly matches song titles, so artist names work best.
class Mix {
  const Mix({
    required this.id,
    required this.title,
    required this.queries,
    this.subtitle = '',
  });

  final String id;
  final String title;
  final List<String> queries;
  final String subtitle;
}

class UserPlaylist {
  const UserPlaylist({
    required this.id,
    required this.name,
    required this.tracks,
  });

  final String id;
  final String name;
  final List<Track> tracks;

  UserPlaylist copyWith({String? name, List<Track>? tracks}) => UserPlaylist(
    id: id,
    name: name ?? this.name,
    tracks: tracks ?? this.tracks,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'tracks': tracks.map((t) => t.toJson()).toList(),
  };

  factory UserPlaylist.fromJson(Map<String, dynamic> json) => UserPlaylist(
    id: json['id'] as String,
    name: json['name'] as String,
    tracks: (json['tracks'] as List)
        .map((t) => Track.fromJson(t as Map<String, dynamic>))
        .toList(),
  );
}

class LyricLine {
  const LyricLine(this.time, this.text);

  /// Null for unsynced (plain) lyrics.
  final Duration? time;
  final String text;
}

class Lyrics {
  const Lyrics(this.lines);

  final List<LyricLine> lines;

  bool get isSynced => lines.isNotEmpty && lines.first.time != null;
}
