import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

class Track {
  final String title;
  final String artist;
  final String url; // HTTP stream or asset path

  const Track({required this.title, required this.artist, required this.url});
}

/// A small curated cycling playlist (royalty-free streams via radio).
final _playlist = [
  const Track(
      title: 'LoFi Cycling Beats',
      artist: 'Radio LoFi',
      url: 'https://streams.ilovemusic.de/iloveradio17.mp3'),
  const Track(
      title: 'Electronic Ride',
      artist: 'Radio Elite',
      url: 'https://streams.ilovemusic.de/iloveradio2.mp3'),
];

class MusicState {
  final bool isPlaying;
  final int trackIndex;
  final Duration position;
  final Duration duration;

  const MusicState({
    this.isPlaying = false,
    this.trackIndex = 0,
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });

  Track get currentTrack => _playlist[trackIndex % _playlist.length];
  List<Track> get playlist => _playlist;

  MusicState copyWith({
    bool? isPlaying,
    int? trackIndex,
    Duration? position,
    Duration? duration,
  }) =>
      MusicState(
        isPlaying: isPlaying ?? this.isPlaying,
        trackIndex: trackIndex ?? this.trackIndex,
        position: position ?? this.position,
        duration: duration ?? this.duration,
      );
}

class MusicNotifier extends StateNotifier<MusicState> {
  final AudioPlayer _player = AudioPlayer();

  MusicNotifier() : super(const MusicState()) {
    _player.positionStream.listen((pos) {
      state = state.copyWith(position: pos);
    });
    _player.durationStream.listen((d) {
      if (d != null) state = state.copyWith(duration: d);
    });
    _player.playerStateStream.listen((ps) {
      state = state.copyWith(isPlaying: ps.playing);
    });
  }

  Future<void> playPause() async {
    if (state.isPlaying) {
      await _player.pause();
    } else {
      if (_player.audioSource == null) {
        await _loadTrack(state.trackIndex);
      }
      await _player.play();
    }
  }

  Future<void> next() async {
    final idx = (state.trackIndex + 1) % _playlist.length;
    state = state.copyWith(trackIndex: idx);
    await _loadTrack(idx);
    await _player.play();
  }

  Future<void> previous() async {
    final idx = (state.trackIndex - 1 + _playlist.length) % _playlist.length;
    state = state.copyWith(trackIndex: idx);
    await _loadTrack(idx);
    await _player.play();
  }

  Future<void> _loadTrack(int idx) async {
    final track = _playlist[idx % _playlist.length];
    await _player.setUrl(track.url);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}

final musicProvider =
    StateNotifierProvider<MusicNotifier, MusicState>((_) => MusicNotifier());
