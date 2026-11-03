import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/models.dart';
import '../../sources/source.dart';
import 'dsp.dart';
import 'pcm_decoder_stub.dart' if (dart.library.io) 'pcm_decoder_io.dart';

/// Works out tempo, beat grid, key, silences and loudness of tracks in the background, one at a time,
/// and remembers the results for the session. Automix uses them as soon as both songs of a
/// transition are known; if analysis fails or is late, it falls back to a plain crossfade.
class AutomixAnalyzer {
  AutomixAnalyzer._();
  static final AutomixAnalyzer I = AutomixAnalyzer._();

  static bool get supported => pcmDecodingSupported;

  final _done = <String, TrackProfile?>{};
  final _pending = <String, Future<TrackProfile?>>{};
  Future<void> _chain = Future.value();

  TrackProfile? cached(String mediaId) => _done[mediaId];
  bool known(String mediaId) => _done.containsKey(mediaId);

  Future<TrackProfile?> analyze(Track t, Playable p) {
    if (!supported || p.url == null) return Future.value(null);
    if (_done.containsKey(t.mediaId)) return Future.value(_done[t.mediaId]);
    return _pending.putIfAbsent(t.mediaId, () {
      final c = Completer<TrackProfile?>();
      _chain = _chain.then((_) async {
        try {
          if (t.durationMs > 15 * 60 * 1000) {
            _done[t.mediaId] = null;
            c.complete(null);
            return;
          }
          final pcm = await decodeToPcm(p);
          final profile = pcm == null ? null : await compute(analyzeJob, PcmJob(pcm, 11025));
          _done[t.mediaId] = profile;
          if (profile != null) {
            debugPrint('Automix: ${t.title} -> ${profile.bpm.toStringAsFixed(1)} BPM, key ${profile.key}, '
                'conf ${profile.confidence.toStringAsFixed(2)}');
          }
          c.complete(profile);
        } catch (e) {
          debugPrint('Automix: analysis failed: $e');
          _done[t.mediaId] = null;
          c.complete(null);
        } finally {
          _pending.remove(t.mediaId);
        }
      });
      return c.future;
    });
  }
}
