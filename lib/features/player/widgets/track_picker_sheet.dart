import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/player/app_player.dart';

/// Shows the audio/subtitle track picker as a modal bottom sheet.
/// Returns the dismissal future so callers can re-enter immersive mode.
Future<void> showTrackPicker(BuildContext context, AppPlayer player) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _TrackPickerSheet(player: player),
  );
}

// ─────────────────────────────────────────────────────────────────────────────

class _TrackPickerSheet extends StatefulWidget {
  const _TrackPickerSheet({required this.player});
  final AppPlayer player;

  @override
  State<_TrackPickerSheet> createState() => _TrackPickerSheetState();
}

class _TrackPickerSheetState extends State<_TrackPickerSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tracks = widget.player.tracks;
    final selAudio    = widget.player.selectedAudioTrack.id;
    final selSubtitle = widget.player.selectedSubtitleTrack.id;

    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          // Tabs
          TabBar(
            controller: _tabs,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: 'Audio'),
              Tab(text: 'Subtitles'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                // Audio tracks
                _TrackList(
                  tracks: tracks.audio,
                  selectedId: selAudio,
                  noTracksLabel: 'No audio tracks detected',
                  labelOf: _audioLabel,
                  onSelect: (t) async {
                    await widget.player.setAudioTrack(t);
                    if (mounted) setState(() {});
                  },
                ),
                // Subtitle tracks
                _TrackList(
                  tracks: tracks.subtitle,
                  selectedId: selSubtitle,
                  noTracksLabel: 'No subtitles available',
                  labelOf: _subLabel,
                  onSelect: (t) async {
                    await widget.player.setSubtitleTrack(t);
                    if (mounted) setState(() {});
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _audioLabel(AppTrack t) {
    if (t.id == 'auto') return 'Auto';
    if (t.id == 'no') return 'None';
    final parts = <String>[];
    if (t.language?.isNotEmpty == true) parts.add(t.language!.toUpperCase());
    if (t.title?.isNotEmpty == true) parts.add(t.title!);
    if (parts.isEmpty) parts.add('Track ${t.id}');
    return parts.join(' — ');
  }

  static String _subLabel(AppTrack t) {
    if (t.id == 'auto') return 'Auto';
    if (t.id == 'no') return 'Off';
    final parts = <String>[];
    if (t.language?.isNotEmpty == true) parts.add(t.language!.toUpperCase());
    if (t.title?.isNotEmpty == true) parts.add(t.title!);
    if (parts.isEmpty) parts.add('Track ${t.id}');
    return parts.join(' — ');
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _TrackList extends StatelessWidget {
  const _TrackList({
    required this.tracks,
    required this.selectedId,
    required this.noTracksLabel,
    required this.labelOf,
    required this.onSelect,
  });

  final List<AppTrack> tracks;
  final String selectedId;
  final String noTracksLabel;
  final String Function(AppTrack) labelOf;
  final Future<void> Function(AppTrack) onSelect;

  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.track_changes_outlined,
                color: AppColors.textMuted, size: 40),
            const SizedBox(height: 12),
            Text(noTracksLabel,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 14)),
          ],
        ),
      );
    }

    // Seed focus on the currently-selected track (or the first one) so the
    // sheet opens with a visible highlight on a TV instead of nothing focused.
    final hasSelection = tracks.any((t) => t.id == selectedId);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: tracks.length,
      itemBuilder: (_, i) {
        final track = tracks[i];
        final selected = track.id == selectedId;
        return ListTile(
          autofocus: selected || (!hasSelection && i == 0),
          leading: Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            color: selected ? AppColors.primary : AppColors.textMuted,
            size: 20,
          ),
          title: Text(
            labelOf(track),
            style: TextStyle(
              color: selected ? AppColors.textPrimary : AppColors.textSecondary,
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          onTap: () => onSelect(track),
          dense: true,
        );
      },
    );
  }
}
