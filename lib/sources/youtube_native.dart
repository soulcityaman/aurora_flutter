import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../core/models.dart';
import '../engine/google_clients.dart';
import '../core/settings.dart';
import 'source.dart';
import 'stream_proxy_stub.dart' if (dart.library.io) 'stream_proxy_io.dart';
import 'yt_fallback.dart';
import 'yt_innertube.dart';
import 'ytmusic.dart';

/// YouTube via youtube_explode_dart (iOS, macOS, Windows, Linux). Not usable in browsers.
class YouTubeNativeSource implements MusicSource {
  YouTubeNativeSource([this._settings])
      : _yt = YoutubeExplode(),
        _fallback = YtFallback(_settings);
  final YtFallback _fallback;
  final _ytm = YtMusicSearch();
  final _tube = YtInnerTube();
  final Settings? _settings;

  final YoutubeExplode _yt;

  @override
  SourceKind get kind => SourceKind.youtube;

  @override
  Future<List<Track>> search(String query, {int limit = 20}) async {
    // YouTube Music first (clean song results); plain YouTube search only if it returns nothing.
    final music = await _ytm.songs(query, limit: limit);
    if (music.isNotEmpty) return music;
    final results = await _yt.search.search(query);
    final out = <Track>[];
    for (final v in results) {
      final d = v.duration;
      // Skip live streams and mixes; music tracks are short.
      if (d == null || d.inSeconds < 30 || d.inMinutes > 15) continue;
      out.add(Track(
        mediaId: TrackKeys.youtube(v.id.value),
        title: decodeEntities(v.title),
        artist: v.author.replaceAll(RegExp(r' - Topic$'), ''),
        durationMs: d.inMilliseconds,
        artworkUri: 'https://i.ytimg.com/vi/${v.id.value}/hqdefault.jpg',
        uri: TrackKeys.youtube(v.id.value),
      ));
      if (out.length >= limit) break;
    }
    return out;
  }

  /// Clients tried in order. androidVr and ios hand out direct URLs (no JavaScript challenge), so they
  /// work without a JS runtime; tv and safari are the fallbacks.
  static final _clientOrder = <List<YoutubeApiClient>>[
    [YoutubeApiClient.androidVr],
    [YoutubeApiClient.ios],
    [YoutubeApiClient.tv],
    [YoutubeApiClient.safari],
  ];

  final _probe = http.Client();

  /// Tries every route in turn; a route only counts once its audio has actually been downloaded, because
  /// some links answer a tiny probe but refuse the real transfer (HTTP 403 without a PO token).
  @override
  Future<Playable?> stream(String rawId) async {
    final q = _settings?.quality ?? 2;
    await for (final cand in _tube.candidates(rawId, quality: q)) {
      final ok = await fetchPlayable(cand);
      if (ok != null) return ok;
    }
    for (final clients in _clientOrder) {
      try {
        final manifest = await _yt.videos.streamsClient.getManifest(rawId, ytClients: clients);
        final audio = manifest.audioOnly.toList();
        if (audio.isEmpty) continue;
        final mp4 = audio.where((s) => s.container == StreamContainer.mp4).toList();
        final pool = mp4.isNotEmpty ? mp4 : audio;
        pool.sort((a, b) => b.bitrate.compareTo(a.bitrate));
        final ordered = q <= 0 ? pool.reversed.toList() : (q == 1 ? [pool[pool.length ~/ 2], ...pool] : pool);
        for (final candidate in ordered.take(2)) {
          final url = candidate.url.toString();
          final ok = await fetchPlayable(Playable.url(url, headers: googleVideoHeaders(url), kbps: (candidate.bitrate.bitsPerSecond / 1000).round()));
          if (ok != null) return ok;
        }
      } catch (e) {
        debugPrint('YouTube client failed for $rawId: ${'$e'.split('\n').first}');
      }
    }
    final fb = await _fallback.stream(rawId, quality: q);
    return fb;
  }

  /// A 2-byte ranged GET with the headers the player will use: proves the URL is not a 403.
  Future<bool> _reachable(String url, Map<String, String> headers) async {
    try {
      final res = await _probe
          .get(Uri.parse(url), headers: {...headers, 'Range': 'bytes=0-1'})
          .timeout(const Duration(seconds: 8));
      return res.statusCode == 200 || res.statusCode == 206;
    } catch (_) {
      return false;
    }
  }
}
