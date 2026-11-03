import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/models.dart';
import '../theme/theme.dart';
import 'artwork.dart';
import 'custom_mix.dart';
import 'like_button.dart';
import 'playlists.dart';

class LargeTitle extends StatelessWidget {
  const LargeTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Row(children: [
          Expanded(child: Text(text, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.5))),
          if (trailing != null) trailing!,
        ]),
      );
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key, this.padding = const EdgeInsets.fromLTRB(20, 20, 20, 8)});
  final String text;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding,
        child: Text(text, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
      );
}

String sourceLabel(Track t) => switch (t.kind) {
      SourceKind.youtube => 'YouTube',
      SourceKind.saavn => 'JioSaavn',
      SourceKind.local => '',
      SourceKind.meta => '',
    };

class TrackRow extends StatelessWidget {
  const TrackRow({
    super.key,
    required this.track,
    required this.onTap,
    this.index,
    this.showArtwork = true,
  });

  final Track track;
  final VoidCallback onTap;
  final int? index;
  final bool showArtwork;

  @override
  Widget build(BuildContext context) {
    final backend = AppController.I.backend;
    return ValueListenableBuilder<Snapshot>(
      valueListenable: backend.snapshot,
      builder: (context, snap, _) {
        final current = snap.current?.mediaId == track.mediaId;
        final badge = sourceLabel(track);
        return InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(children: [
              if (index != null)
                SizedBox(
                  width: 28,
                  child: Text('$index', style: TextStyle(color: context.secondaryText, fontSize: 15)),
                ),
              if (showArtwork) ...[Artwork(track, size: 48, radius: 6, px: 160), const SizedBox(width: 12)],
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500, color: current ? context.secondaryText : null)),
                  const SizedBox(height: 2),
                  Row(children: [
                    if (badge.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: context.tertiaryText, width: 0.7),
                        ),
                        child: Text(badge, style: TextStyle(fontSize: 9.5, color: context.secondaryText)),
                      ),
                    Expanded(
                      child: Text(track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14, color: context.secondaryText)),
                    ),
                  ]),
                ]),
              ),
              if (track.durationMs > 0)
                Text(formatTime(track.durationMs), style: TextStyle(color: context.secondaryText, fontSize: 13)),
              LikeButton(track: track, size: 21),
              TrackMenu(track: track),
            ]),
          ),
        );
      },
    );
  }
}

class TrackMenu extends StatelessWidget {
  const TrackMenu({super.key, required this.track});
  final Track track;

  @override
  Widget build(BuildContext context) {
    final backend = AppController.I.backend;
    return PopupMenuButton<String>(
      tooltip: 'More',
      icon: Icon(Icons.more_horiz_rounded, color: context.secondaryText),
      onSelected: (v) {
        if (v == 'next') backend.playNext(track);
        if (v == 'queue') backend.addToQueue(track);
        if (v == 'playlist') addToPlaylistDialog(context, track);
        if (v == 'like') UserPlaylists.toggleLike(track);
        if (v == 'mix') showCustomMixDialog(context, track);
      },
      itemBuilder: (_) => [
        PopupMenuItem(value: 'like', child: Text(UserPlaylists.isLiked(track.mediaId) ? 'Remove from Liked Songs' : 'Like')),
        const PopupMenuItem(value: 'next', child: Text('Play Next')),
        const PopupMenuItem(value: 'queue', child: Text('Add to Queue')),
        const PopupMenuItem(value: 'playlist', child: Text('Add to Playlist')),
        PopupMenuItem(value: 'mix', child: Text(AppController.I.settings.mixOverrides.containsKey(track.mediaId) ? 'Custom transition (set)…' : 'Custom transition…')),
      ],
    );
  }
}

class AlbumCard extends StatelessWidget {
  const AlbumCard({super.key, required this.album, required this.onTap, this.width = 160});
  final Album album;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: width,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Artwork(album.asArtTrack, size: width, radius: 10, px: 400),
            const SizedBox(height: 8),
            Text(album.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            Text(album.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: context.secondaryText)),
          ]),
        ),
      );
}

class AccentButton extends StatelessWidget {
  const AccentButton({super.key, required this.icon, required this.label, required this.onTap, this.filled = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) => Material(
        color: filled ? context.accent : context.chipFill,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: filled ? context.onAccent : context.accent, size: 20),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: filled ? context.onAccent : context.accent)),
            ]),
          ),
        ),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.action});
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 56, color: context.tertiaryText),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: context.secondaryText)),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ]),
        ),
      );
}
