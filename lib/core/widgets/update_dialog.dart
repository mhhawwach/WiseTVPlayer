import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
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

class _UpdateDialog extends StatelessWidget {
  const _UpdateDialog({required this.info});
  final UpdateInfo info;

  @override
  Widget build(BuildContext context) {
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
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (info.required)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.liveRed.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.liveRed.withAlpha(80)),
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
          if (info.notes.isNotEmpty)
            Text(
              info.notes,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13, height: 1.5),
            ),
        ],
      ),
      actions: [
        if (!info.required)
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Later',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
        FilledButton.icon(
          onPressed: () async {
            if (info.downloadUrl.isNotEmpty) {
              final uri = Uri.tryParse(info.downloadUrl);
              if (uri != null) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            }
            if (context.mounted) Navigator.of(context).pop(true);
          },
          icon: const Icon(Icons.download_rounded, size: 18),
          label: const Text('Update Now'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
