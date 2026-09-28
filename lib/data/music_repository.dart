import 'models.dart';

/// Everything the UI needs from a music catalog. Implement this again for
/// another provider and swap it in `main.dart`.
abstract class MusicRepository {
  Future<List<Track>> searchTracks(String query, {int limit = 20});
  Future<List<ArtistSummary>> searchArtists(String query, {int limit = 10});
  Future<List<AlbumSummary>> searchAlbums(String query, {int limit = 10});

  /// Best match for an artist name, or null if nothing was found.
  Future<ArtistSummary?> findArtist(String name);

  Future<ArtistDetails> artist(String id);
  Future<AlbumDetails> album(String id);
}
