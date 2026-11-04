import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';

/// Controller for querying and playing local offline audio files
/// directly from the user's device storage.
class LocalAudioController extends ChangeNotifier {
  static const _channel = MethodChannel('com.mobilions.music_app/local_audio');

  bool _loading = false;
  bool _hasPermission = false;
  List<Track> _tracks = [];
  String? _error;

  bool get isLoading => _loading;
  bool get hasPermission => _hasPermission;
  List<Track> get tracks => List.unmodifiable(_tracks);
  String? get error => _error;
  int get count => _tracks.length;

  Future<void> checkAndLoad() async {
    try {
      final permitted =
          await _channel.invokeMethod<bool>('checkPermission') ?? false;
      _hasPermission = permitted;
      if (permitted) {
        await loadTracks();
      } else {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('LocalAudio checkPermission error: $e');
    }
  }

  Future<void> requestAndLoad() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final granted =
          await _channel.invokeMethod<bool>('requestPermission') ?? false;
      _hasPermission = granted;
      if (granted) {
        await loadTracks();
      } else {
        _loading = false;
        _error = 'Audio permission is required to browse device files.';
        notifyListeners();
      }
    } catch (e) {
      _loading = false;
      _error = 'Permission request failed: $e';
      notifyListeners();
    }
  }

  Future<void> loadTracks() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final rawList =
          await _channel.invokeMethod<List<dynamic>>('getLocalAudio');
      if (rawList != null) {
        _tracks = rawList
            .map((item) {
              final map = Map<String, dynamic>.from(item as Map);
              final id = map['id']?.toString() ?? UniqueKey().toString();
              final durationMs = (map['duration'] as num?)?.toInt() ?? 0;
              final title = (map['title'] as String?)?.trim();
              final artist = (map['artist'] as String?)?.trim();
              final album = (map['album'] as String?)?.trim();
              final uri = (map['uri'] as String?) ?? '';

              return Track(
                id: 'local_$id',
                title: (title != null && title.isNotEmpty)
                    ? title
                    : 'Audio $id',
                artist: (artist != null && artist.isNotEmpty)
                    ? artist
                    : 'Device Audio',
                album: (album != null && album.isNotEmpty)
                    ? album
                    : 'Local Files',
                albumId: 'device_audio',
                imageUrl: '',
                streamUrl: uri,
                duration: Duration(milliseconds: durationMs),
              );
            })
            .where((t) => t.streamUrl.isNotEmpty && t.duration.inSeconds >= 3)
            .toList();
      }
    } catch (e) {
      _error = 'Could not load local tracks: $e';
      debugPrint('LocalAudio load error: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
