import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'source.dart';

/// googlevideo links from the app clients only work with the client's own User-Agent and bounded
/// range requests, and the audio engine cannot open them directly. So the song is downloaded here, with
/// the right headers, into a temporary file (a few MB, about a second) and the engine plays that file:
/// a plain local file always opens, seeks instantly and decodes fine for Automix analysis.
const _chunk = 4 * 1024 * 1024;
const _keepFiles = 40;
final _client = http.Client();
final _inflight = <String, Future<File?>>{};

/// Makes [p] playable by the engine: googlevideo streams are downloaded to a file; null when that fails
/// (so the caller can try the next candidate). Other URLs pass through untouched.
Future<Playable?> fetchPlayable(Playable p) async {
  final url = p.url;
  if (url == null || !url.contains('googlevideo.com')) return p;
  final f = await _download(p);
  return f == null ? null : Playable.url(f.path, kbps: p.kbps);
}

Future<Playable> proxyPlayable(Playable p) async {
  final f = await _download(p);
  return f == null ? p : Playable.url(f.path, kbps: p.kbps);
}

/// For the diagnostics screen: downloads the stream and reports what happened.
Future<String> proxySelfTest(Playable p) async {
  final sw = Stopwatch()..start();
  try {
    final f = await _download(p, force: true);
    if (f == null) return 'FAILED (see console)';
    return 'downloaded ${(await f.length()) ~/ 1024} KB in ${sw.elapsedMilliseconds} ms -> ${f.path}';
  } catch (e) {
    return 'ERROR $e';
  }
}

Future<File?> _download(Playable p, {bool force = false}) {
  final url = p.url;
  if (url == null || !url.contains('googlevideo.com')) return Future.value(null);
  final uri = Uri.parse(url);
  final length = int.tryParse(uri.queryParameters['clen'] ?? '');
  if (length == null || length <= 0 || length > 80 * 1024 * 1024) return Future.value(null);
  final id = (uri.queryParameters['id'] ?? '${url.hashCode}').replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  final mime = uri.queryParameters['mime'] ?? 'audio/mp4';
  final ext = mime.contains('webm') ? 'webm' : 'm4a';
  return _inflight.putIfAbsent('$id.$ext', () async {
    try {
      final dir = Directory('${Directory.systemTemp.path}${Platform.pathSeparator}music_audio_cache');
      await dir.create(recursive: true);
      final file = File('${dir.path}${Platform.pathSeparator}$id.$ext');
      if (!force && await file.exists() && await file.length() == length) return file;
      final part = File('${file.path}.part');
      final sink = part.openWrite();
      try {
        for (var pos = 0; pos < length;) {
          final to = (pos + _chunk - 1).clamp(0, length - 1);
          final r = http.Request('GET', uri)..headers.addAll({...p.headers, 'Range': 'bytes=$pos-$to'});
          final res = await _client.send(r).timeout(const Duration(seconds: 20));
          if (res.statusCode != 200 && res.statusCode != 206) {
            throw HttpException('upstream HTTP ${res.statusCode}');
          }
          await sink.addStream(res.stream.timeout(const Duration(seconds: 30)));
          pos = to + 1;
        }
      } finally {
        await sink.close();
      }
      if (await part.length() != length) throw HttpException('short download ${await part.length()} of $length');
      if (await file.exists()) await file.delete();
      await part.rename(file.path);
      unawaited(_evict(dir));
      return file;
    } catch (e) {
      debugPrint('YouTube download failed: $e');
      return null;
    } finally {
      _inflight.remove('$id.$ext');
    }
  });
}

Future<void> _evict(Directory dir) async {
  try {
    final files = [for (final e in await dir.list().toList()) if (e is File && !e.path.endsWith('.part')) e];
    if (files.length <= _keepFiles) return;
    files.sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));
    for (final f in files.take(files.length - _keepFiles)) {
      await f.delete();
    }
  } catch (_) {}
}
