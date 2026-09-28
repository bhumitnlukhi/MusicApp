import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../data/models.dart';

/// Owns the single [AudioPlayer] and the play queue.
///
/// [queue] always mirrors the player's audio sources in play order, so the
/// Queue screen can show and reorder it directly. Shuffle is implemented by
/// physically reordering the upcoming tracks (and restoring them on toggle
/// off) rather than just_audio's shuffle mode, so there's one source of truth.
class PlayerController extends ChangeNotifier {
  PlayerController({this.onTrackStarted}) {
    _subs.addAll([
      _player.currentIndexStream.listen(_onIndexChanged),
      _player.playerStateStream.listen((_) => notifyListeners()),
      _player.loopModeStream.listen((_) => notifyListeners()),
      _player.errorStream.listen((e) {
        _errors.add("Couldn't play this song (${e.code})");
      }),
    ]);
  }

  final void Function(Track track)? onTrackStarted;

  final _player = AudioPlayer();
  final _subs = <StreamSubscription<Object?>>[];
  final _errors = StreamController<String>.broadcast();

  List<Track> _queue = [];
  int? _index;
  bool _shuffle = false;
  List<Track>? _unshuffledUpcoming;
  String? _lastStartedId;

  // ---- read state ----------------------------------------------------------

  List<Track> get queue => List.unmodifiable(_queue);
  int? get currentIndex => _index;
  Track? get current =>
      _index != null && _index! < _queue.length ? _queue[_index!] : null;
  List<Track> get upNext =>
      _index == null ? const [] : _queue.sublist(_index! + 1);

  bool get isPlaying =>
      _player.playing && _player.processingState != ProcessingState.completed;
  bool get isBuffering =>
      _player.processingState == ProcessingState.loading ||
      _player.processingState == ProcessingState.buffering;
  bool get shuffleEnabled => _shuffle;
  LoopMode get loopMode => _player.loopMode;

  Stream<Duration> get positionStream => _player.positionStream;
  Duration get position => _player.position;
  Duration get duration =>
      _player.duration ?? current?.duration ?? Duration.zero;

  /// User-facing playback errors, shown as snackbars by the shell.
  Stream<String> get errors => _errors.stream;

  // ---- playback ------------------------------------------------------------

  Future<void> playTracks(List<Track> tracks, {int index = 0}) async {
    if (tracks.isEmpty) return;
    _queue = List.of(tracks);
    _index = index;
    _shuffle = false;
    _unshuffledUpcoming = null;
    notifyListeners();
    try {
      await _player.setAudioSources(
        _queue.map(_source).toList(),
        initialIndex: index,
      );
      unawaited(_player.play());
    } on PlayerInterruptedException {
      // A newer playTracks call replaced this one.
    } catch (e) {
      _errors.add("Couldn't start playback");
      debugPrint('playTracks failed: $e');
    }
  }

  Future<void> shufflePlay(List<Track> tracks) async {
    if (tracks.isEmpty) return;
    await playTracks(List.of(tracks)..shuffle());
  }

  void togglePlay() {
    if (current == null) return;
    if (_player.processingState == ProcessingState.completed) {
      _player.seek(Duration.zero, index: 0);
      _player.play();
    } else if (_player.playing) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  void next() {
    if (_player.hasNext) _player.seekToNext();
  }

  void previous() {
    if (_player.position > const Duration(seconds: 3) || !_player.hasPrevious) {
      _player.seek(Duration.zero);
    } else {
      _player.seekToPrevious();
    }
  }

  void seek(Duration position) => _player.seek(position);

  void jumpTo(int index) {
    _player.seek(Duration.zero, index: index);
    _player.play();
  }

  void cycleRepeat() {
    final next = switch (_player.loopMode) {
      LoopMode.off => LoopMode.all,
      LoopMode.all => LoopMode.one,
      LoopMode.one => LoopMode.off,
    };
    _player.setLoopMode(next);
  }

  // ---- queue editing -------------------------------------------------------

  Future<void> playNext(Track track) async {
    if (current == null) return playTracks([track]);
    final at = _index! + 1;
    _queue.insert(at, track);
    notifyListeners();
    await _player.insertAudioSource(at, _source(track));
  }

  Future<void> addToQueue(Track track) async {
    if (current == null) return playTracks([track]);
    _queue.add(track);
    _unshuffledUpcoming?.add(track);
    notifyListeners();
    await _player.addAudioSource(_source(track));
  }

  Future<void> removeAt(int index) async {
    if (index == _index || index < 0 || index >= _queue.length) return;
    final removed = _queue.removeAt(index);
    _unshuffledUpcoming?.remove(removed);
    notifyListeners();
    await _player.removeAudioSourceAt(index);
  }

  /// Moves a track within the queue (indices into [queue]).
  Future<void> move(int from, int to) async {
    if (from == to) return;
    _queue.insert(to, _queue.removeAt(from));
    notifyListeners();
    await _player.moveAudioSource(from, to);
  }

  Future<void> clearUpNext() async {
    if (_index == null || _index! + 1 >= _queue.length) return;
    final start = _index! + 1;
    final end = _queue.length;
    _queue.removeRange(start, end);
    _unshuffledUpcoming = null;
    _shuffle = false;
    notifyListeners();
    await _player.removeAudioSourceRange(start, end);
  }

  Future<void> toggleShuffle() async {
    if (_index == null) return;
    final upcoming = upNext;
    final List<Track> target;
    if (!_shuffle) {
      _unshuffledUpcoming = List.of(upcoming);
      target = List.of(upcoming)..shuffle();
    } else {
      // Restore the original order; tracks added while shuffled go last.
      final original = _unshuffledUpcoming ?? const <Track>[];
      target = [
        ...original.where(upcoming.contains),
        ...upcoming.where((t) => !original.contains(t)),
      ];
      _unshuffledUpcoming = null;
    }
    _shuffle = !_shuffle;
    notifyListeners();
    await _reorderUpcoming(target);
  }

  /// Applies [target] as the new upcoming order via the minimum player moves.
  Future<void> _reorderUpcoming(List<Track> target) async {
    final start = _index! + 1;
    for (var i = 0; i < target.length; i++) {
      final want = start + i;
      final from = _queue.indexOf(target[i], want);
      if (from == -1 || from == want) continue;
      _queue.insert(want, _queue.removeAt(from));
      await _player.moveAudioSource(from, want);
    }
    notifyListeners();
  }

  // ---- internals -----------------------------------------------------------

  void _onIndexChanged(int? index) {
    _index = index;
    final track = current;
    if (track != null && track.id != _lastStartedId) {
      _lastStartedId = track.id;
      onTrackStarted?.call(track);
    }
    notifyListeners();
  }

  AudioSource _source(Track t) => AudioSource.uri(
    Uri.parse(t.streamUrl),
    // Shown in the notification / lock screen by just_audio_background.
    tag: MediaItem(
      id: t.id,
      title: t.title,
      artist: t.artist,
      album: t.album,
      duration: t.duration,
      artUri: t.imageUrl.isEmpty ? null : Uri.parse(t.imageUrl),
    ),
  );

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _errors.close();
    _player.dispose();
    super.dispose();
  }
}
