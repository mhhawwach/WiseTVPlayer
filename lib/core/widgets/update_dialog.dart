import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../services/update_installer.dart';
import '../../services/update_service.dart';

/// Shows the "Update Available" dialog.
///
/// - Optional updates have a **Later** button.
/// - Required updates only have **Update Now** — the user cannot dismiss.
///
/// Returns `true` if the user chose to update, `false` if they deferred.
Future<bool> showUpdateDialog(BuildContext context, UpdateInfo info) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: !info.required,
    builder: (_) => _UpdateDialog(info: info),
  );
  return result ?? false;
}

// ─────────────────────────────────────────────────────────────────────────────

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({required this.info});
  final UpdateInfo info;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _busy = false;
  double? _progress;
  String? _message;
  String? _downloaded; // reused when the user retries after granting access

  Future<void> _update() async {
    final info = widget.info;
    if (!UpdateInstaller.supported) {
      final uri = Uri.tryParse(info.downloadUrl);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      if (mounted) Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
      _progress = null;
    });
    try {
      final path = _downloaded ??
          await UpdateInstaller.download(info, onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          });
      if (!mounted) return; // "Later" while downloading: don't install
      _downloaded = path;
      final problem = await UpdateInstaller.install(path);
      if (!mounted) return;
      if (problem == null) {
        Navigator.of(context).pop(true);
        return;
      }
      setState(() {
        _busy = false;
        _message = problem;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = 'The download failed. Check the connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.system_update_rounded,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Update Available',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Version ${info.version}',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 320),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (info.required)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.liveRed.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: AppColors.liveRed.withAlpha(80)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: AppColors.liveRed, size: 14),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'This update is required to continue.',
                          style: TextStyle(
                              color: AppColors.liveRed,
                              fontSize: 12,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_busy) ...[
                Text(
                  _progress == null
                      ? 'Starting download…'
                      : 'Downloading… ${(_progress! * 100).round()}%',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: _progress),
                const SizedBox(height: 12),
              ],
              if (_message != null) ...[
                Text(
                  _message!,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 12),
              ],
              if (info.notes.isNotEmpty)
                Text(
                  info.notes,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13, height: 1.5),
                ),
            ],
          ),
        ),
      ),
      actions: [
        if (!info.required)
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Later',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
        FilledButton.icon(
          // Initial D-pad focus — without an anchor the remote had nothing
          // focused inside the dialog and key presses leaked to the page.
          autofocus: true,
          // Never disabled: a disabled button drops D-pad focus mid-download.
          onPressed: _busy ? () {} : _update,
          icon: const Icon(Icons.download_rounded, size: 18),
          label: Text(_message == null ? 'Update Now' : 'Try Again'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
