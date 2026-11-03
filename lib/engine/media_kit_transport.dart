import 'dart:async';

import 'package:media_kit/media_kit.dart' hide Playable;

import '../sources/source.dart';
import 'eq.dart';
import 'transport.dart';

/// mpv through media_kit: Windows, Linux, macOS and iOS. Supports request headers (googlevideo needs
/// them), per-instance volume for crossfades, and a real equalizer through mpv's audio filters.
class MediaKitTransport implements Transport {
  MediaKitTransport() {
    _player = Player(configuration: const PlayerConfiguration(title: 'Music'));
    _subs.addAll([
      _player.stream.playing.listen(_playing.add),
      _player.stream.buffering.listen(_buffering.add),
      _player.stream.completed.listen((done) {
        if (done && !_completedFired) {
          _completedFired = true;
          _completed.add(null);
        }
      }),
      _player.stream.position.listen((d) => _position.add(d.inMilliseconds)),
      _player.stream.error.listen((e) {
        if (e.isEmpty) return;
        // A DJ-filter graph this mpv build rejects must never stop playback: drop it for good.
        if (_mixChain && e.toLowerCase().contains('filter')) {
          _mixBroken = true;
          _mixChain = false;
          unawaited(_applyAf());
        }
        _errors.add(e);
      }),
    ]);
  }

  late final Player _player;
  final _subs = <StreamSubscription<dynamic>>[];
  final _playing = StreamController<bool>.broadcast();
  final _buffering = StreamController<bool>.broadcast();
  final _completed = StreamController<void>.broadcast();
  final _errors = StreamController<String>.broadcast();
  final _position = StreamController<int>.broadcast();
  bool _completedFired = false;
  String _lastFilter = '';

  @override
  Stream<bool> get playing => _playing.stream;
  @override
  Stream<bool> get buffering => _buffering.stream;
  @override
  Stream<void> get completed => _completed.stream;
  @override
  Stream<String> get errors => _errors.stream;
  @override
  Stream<int> get positionMs => _position.stream;
  @override
  int get durationMs => _player.state.duration.inMilliseconds;
  @override
  int get currentPositionMs => _player.state.position.inMilliseconds;
  @override
  bool get supportsEq => true;

  @override
  bool canPlay(Playable p) => p.url != null;

  @override
  Future<void> open(Playable p, {int startMs = 0}) async {
    _completedFired = false;
    final headers = Map<String, String>.of(p.headers);
    final ua = headers.remove('User-Agent');
    final native = _player.platform;
    if (native is NativePlayer) {
      // mpv keeps its own User-Agent setting separate from custom header fields.
      await native.setProperty('user-agent', ua ?? 'Mozilla/5.0');
    }
    await _player.open(
      Media(p.url!, httpHeaders: headers.isEmpty ? null : headers, start: startMs > 0 ? Duration(milliseconds: startMs) : null),
      play: false,
    );
  }

  @override
  Future<void> play() => _player.play();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> seek(int ms) => _player.seek(Duration(milliseconds: ms));
  @override
  Future<void> setSpeed(double speed) => _player.setRate(speed);
  @override
  Future<void> setVolume(double volume) => _player.setVolume((volume.clamp(0.0, 1.0)) * 100);

  String _eqFilter = '';
  bool _mixChain = false;
  bool _mixBroken = false;

  Future<void> _applyAf() async {
    final parts = [
      if (_eqFilter.isNotEmpty) _eqFilter,
      if (_mixChain) '@mix:lavfi=[highpass@hp=f=20,lowpass@lp=f=18000]',
    ];
    final platform = _player.platform;
    if (platform is NativePlayer) await platform.setProperty('af', parts.join(','));
  }

  @override
  Future<void> setEq(bool enabled, List<double> gainsDb) async {
    final filter = mpvEqFilter(enabled, gainsDb);
    if (filter == _lastFilter) return;
    _lastFilter = filter;
    _eqFilter = filter;
    await _applyAf();
  }

  @override
  bool get supportsMixFilter => !_mixBroken;

  @override
  Future<void> setMixChain(bool on) async {
    if (_mixBroken || _mixChain == on) return;
    _mixChain = on;
    await _applyAf();
  }

  @override
  Future<void> setMixFilter(double highpassHz, double lowpassHz) async {
    if (!_mixChain) return;
    final platform = _player.platform;
    if (platform is! NativePlayer) return;
    try {
      await platform.command(['af-command', 'mix', 'frequency', highpassHz.toStringAsFixed(1), 'hp']);
      await platform.command(['af-command', 'mix', 'frequency', lowpassHz.toStringAsFixed(1), 'lp']);
    } catch (_) {}
  }

  @override
  Future<List<AudioOutput>> outputs() async =>
      [for (final d in _player.state.audioDevices) AudioOutput(d.name, d.description.isEmpty ? d.name : d.description)];

  @override
  Future<void> setOutput(String id) async {
    final d = _player.state.audioDevices.where((e) => e.name == id).firstOrNull;
    if (d != null) await _player.setAudioDevice(d);
  }

  @override
  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    await _player.dispose();
  }
}
