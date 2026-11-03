import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/settings.dart';
import '../theme/theme.dart';
import 'diagnostics_screen.dart';
import '../widgets/common.dart';
import 'equalizer_screen.dart';
import 'home.dart';
import 'import_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final Settings s = AppController.I.settings;
  late final _proxy = TextEditingController(text: s.proxyUrl);
  late final _hosts = TextEditingController(text: s.invidiousHosts.join('\n'));

  @override
  void dispose() {
    _proxy.dispose();
    _hosts.dispose();
    super.dispose();
  }

  Widget _label(BuildContext context, String t) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 30, 0, 10),
        child: Text(t, style: TextStyle(fontSize: 13, letterSpacing: 0.8, fontWeight: FontWeight.w700, color: context.secondaryText)),
      );

  Widget _row(BuildContext context, {required Widget leading, required String title, required String sub, Widget? trailing, VoidCallback? onTap}) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(children: [
            SizedBox(width: 44, child: Center(child: leading)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(sub, style: TextStyle(fontSize: 14, color: context.secondaryText)),
              ]),
            ),
            if (trailing != null) trailing,
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final backend = AppController.I.backend;
    const qualities = ['Low', 'Medium', 'High', 'Lossless'];
    const qualityNote = [
      '96 kbps. Saves data.',
      '160 kbps.',
      'Up to 320 kbps where the source has it.',
      'Best available. Neither JioSaavn nor YouTube Music serves lossless audio.',
    ];
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: ListView(padding: const EdgeInsets.fromLTRB(28, 24, 28, kListBottomPad), children: [
          const Text('Settings', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
          _label(context, 'APPEARANCE'),
          Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'system', label: Text('System'), icon: Icon(Icons.brightness_auto_rounded)),
                ButtonSegment(value: 'light', label: Text('Light'), icon: Icon(Icons.light_mode_rounded)),
                ButtonSegment(value: 'dark', label: Text('Dark'), icon: Icon(Icons.dark_mode_rounded)),
              ],
              selected: {s.themeMode},
              onSelectionChanged: (v) => setState(() => s.themeMode = v.first),
            ),
          ),
          _row(
            context,
            leading: const Icon(Icons.blur_on_rounded, size: 26),
            title: 'Particle grid',
            sub: 'Dots that react to your pointer in the background',
            trailing: Switch(value: s.particles, onChanged: (v) => setState(() => s.particles = v)),
          ),
          _label(context, 'LIBRARY'),
          _row(
            context,
            leading: const Icon(Icons.playlist_add_rounded, size: 26),
            title: 'Import a playlist',
            sub: 'From Spotify, Apple Music, YouTube, Deezer, or a CSV',
            trailing: Icon(Icons.chevron_right_rounded, color: context.secondaryText),
            onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const ImportScreen())),
          ),
          _label(context, 'PLAYBACK'),
          _row(
            context,
            leading: const Icon(Icons.equalizer_rounded, size: 26),
            title: 'Equalizer',
            sub: s.eqEnabled ? 'On · ${s.eqPreset}' : 'Off',
            trailing: Icon(Icons.chevron_right_rounded, color: context.secondaryText),
            onTap: () async {
              await Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const EqualizerScreen()));
              setState(() {});
            },
          ),
          _row(
            context,
            leading: const Icon(Icons.auto_awesome_rounded, size: 26),
            title: 'Autoplay',
            sub: 'When the queue ends, keep playing songs you are likely to enjoy',
            trailing: Switch(value: s.autoplay, onChanged: (v) => setState(() => s.autoplay = v)),
          ),
          _row(
            context,
            leading: const Icon(Icons.lyrics_rounded, size: 26),
            title: 'Word-by-word lyrics',
            sub: 'Experimental. Off keeps clean line-by-line lyrics',
            trailing: Switch(value: s.wordLyrics, onChanged: (v) => setState(() => s.wordLyrics = v)),
          ),
          _row(
            context,
            leading: const Icon(Icons.tune_rounded, size: 26),
            title: 'DJ filters in Automix (beta)',
            sub: 'Bass swap and filter sweeps. Turns itself off if your player rejects them',
            trailing: Switch(value: s.mixFilters, onChanged: (v) => setState(() => s.mixFilters = v)),
          ),
          _row(
            context,
            leading: const Icon(Icons.bug_report_outlined, size: 26),
            title: 'YouTube diagnostics',
            sub: 'Test every YouTube route and see which one fails',
            onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const DiagnosticsScreen())),
          ),
          _row(
            context,
            leading: const Icon(Icons.all_inclusive_rounded, size: 26),
            title: 'Automix',
            sub: 'DJ-style blends: matches tempo and bar lines, swaps bass, skips silences (desktop/iOS); smart crossfade elsewhere',
            trailing: Switch(
              value: s.automix,
              onChanged: (v) {
                setState(() => s.automix = v);
                backend.setAutomix(v, s.automixSeconds);
              },
            ),
          ),
          if (s.automix)
            Padding(
              padding: const EdgeInsets.only(left: 56),
              child: Row(children: [
                const Text('Max blend'),
                Expanded(
                  child: Slider(
                    min: 2,
                    max: 30,
                    divisions: 28,
                    label: '${s.automixSeconds.round()} s',
                    value: s.automixSeconds.clamp(2.0, 30.0),
                    onChanged: (v) => setState(() => s.automixSeconds = v),
                    onChangeEnd: (v) => backend.setAutomix(true, v),
                  ),
                ),
                Text('${s.automixSeconds.round()} s'),
              ]),
            ),
          _label(context, 'SOURCES, TRIED IN THIS ORDER'),
          _row(
            context,
            leading: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('1', style: TextStyle(color: context.secondaryText)),
              const SizedBox(width: 10),
              const Icon(Icons.graphic_eq_rounded, size: 22),
            ]),
            title: 'JioSaavn',
            sub: 'Up to 320 kbps · applies after restart',
            trailing: Switch(value: s.saavnEnabled, onChanged: (v) => setState(() => s.saavnEnabled = v)),
          ),
          _row(
            context,
            leading: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('2', style: TextStyle(color: context.secondaryText)),
              const SizedBox(width: 10),
              const Icon(Icons.play_circle_fill_rounded, size: 24),
            ]),
            title: 'YouTube Music',
            sub: 'Lossy · Full catalogue · applies after restart',
            trailing: Switch(value: s.youtubeEnabled, onChanged: (v) => setState(() => s.youtubeEnabled = v)),
          ),
          _label(context, 'AUDIO QUALITY'),
          Wrap(spacing: 10, children: [
            for (var i = 0; i < qualities.length; i++)
              ChoiceChip(
                label: Text(qualities[i]),
                selected: s.quality == i,
                showCheckmark: false,
                selectedColor: context.accent,
                labelStyle: TextStyle(color: s.quality == i ? context.onAccent : context.accent, fontWeight: FontWeight.w600),
                onSelected: (_) => setState(() => s.quality = i),
              ),
          ]),
          const SizedBox(height: 10),
          Text(qualityNote[s.quality], style: TextStyle(fontSize: 13, color: context.secondaryText)),
          if (backend.canAddMusic) ...[
            _label(context, 'THIS DEVICE'),
            _row(
              context,
              leading: const Icon(Icons.create_new_folder_outlined, size: 26),
              title: 'Add Music',
              sub: s.musicFolders.isEmpty ? 'Pick a folder or files' : s.musicFolders.join('\n'),
              onTap: backend.addMusic,
            ),
            _row(context, leading: const Icon(Icons.refresh_rounded, size: 26), title: 'Rescan Library', sub: 'Look for new files', onTap: backend.refreshLibrary),
          ],
          _label(context, 'WEB BUILD'),
          Text(
            'Browsers block direct calls to JioSaavn. Point this at a CORS proxy (tools/cors_proxy_worker.js) '
            'ending in ?url= . YouTube search uses the Invidious hosts below; playback uses the YouTube player.',
            style: TextStyle(color: context.secondaryText, fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _proxy,
            decoration: const InputDecoration(labelText: 'Proxy URL', hintText: 'https://worker.example.workers.dev/?url='),
            onChanged: (v) => s.proxyUrl = v,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _hosts,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Invidious hosts (one per line)'),
            onChanged: (v) => s.invidiousHosts = v.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
          ),
          _label(context, 'ABOUT'),
          Text(
            backend.hasBeatEngine
                ? 'Audio engine: native Media3 with on-device beat detection (Beat This!, ONNX).'
                : 'Audio engine: Dart. Real-time beat detection and spatial audio are Android-only.',
            style: TextStyle(color: context.secondaryText, fontSize: 13),
          ),
        ]),
      ),
    );
  }
}
