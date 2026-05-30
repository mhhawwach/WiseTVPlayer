import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/storage/storage_service.dart';
import '../../core/theme/app_theme.dart';
import '../../services/xtream_service.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final accountInfoProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final id = StorageService.activePlaylistId;
  if (id == null) throw Exception('No active playlist');
  final playlist = StorageService.getPlaylist(id)!;
  return ref.read(xtreamServiceProvider).authenticate(
        playlist.serverUrl,
        playlist.username,
        playlist.password,
      );
});

// ── Screen ────────────────────────────────────────────────────────────────────

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final asyncInfo = ref.watch(accountInfoProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.accountInfo)),
      body: asyncInfo.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    color: AppColors.textMuted, size: 48),
                const SizedBox(height: 16),
                Text(
                  e.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () =>
                      ref.invalidate(accountInfoProvider),
                  icon: const Icon(Icons.refresh),
                  label: Text(s.retry),
                ),
              ],
            ),
          ),
        ),
        data: (data) => _AccountBody(data: data, s: s),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _AccountBody extends StatelessWidget {
  const _AccountBody({required this.data, required this.s});
  final Map<String, dynamic> data;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    final userInfo = data['user_info'] as Map<String, dynamic>? ?? {};
    final serverInfo = data['server_info'] as Map<String, dynamic>? ?? {};

    // Parse user fields
    final username = userInfo['username']?.toString() ?? '—';
    final status = userInfo['status']?.toString() ?? '';
    final isTrial = userInfo['is_trial']?.toString() == '1';
    final activeCons = userInfo['active_cons']?.toString() ?? '0';
    final maxCons = userInfo['max_connections']?.toString() ?? '—';
    final expTimestamp = int.tryParse(
            userInfo['exp_date']?.toString() ?? '') ??
        0;
    final expDate = expTimestamp > 0
        ? DateTime.fromMillisecondsSinceEpoch(expTimestamp * 1000)
        : null;

    // Parse server fields
    final serverUrl = serverInfo['url']?.toString() ?? '—';
    final serverPort = serverInfo['port']?.toString() ?? '';
    final timezone = serverInfo['timezone']?.toString() ?? '—';
    final timeNow = serverInfo['time_now']?.toString() ?? '';

    // Status color
    final isActive =
        status.toLowerCase() == 'active' || status.toLowerCase() == 'enabled';
    final isExpired = status.toLowerCase() == 'expired' ||
        status.toLowerCase() == 'disabled' ||
        status.toLowerCase() == 'banned';

    Color statusColor;
    String statusLabel;
    if (isTrial) {
      statusColor = Colors.orange;
      statusLabel = s.accountTrial;
    } else if (isActive) {
      statusColor = Colors.green;
      statusLabel = s.accountActive;
    } else if (isExpired) {
      statusColor = Colors.red;
      statusLabel = s.accountExpired;
    } else {
      statusColor = AppColors.textMuted;
      statusLabel = status.isNotEmpty ? status : '—';
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── User Info card ─────────────────────────────────────────────────
        _Card(
          title: 'User Info',
          icon: Icons.person_outline_rounded,
          children: [
            _Row(label: 'Username', value: username),
            _Row(
              label: s.accountStatus,
              value: statusLabel,
              valueColor: statusColor,
              valueBadge: true,
            ),
            if (expDate != null)
              _Row(
                label: s.accountExpiry,
                value: _formatDate(expDate),
                valueColor: expDate.isBefore(DateTime.now())
                    ? Colors.red
                    : null,
              ),
            _Row(
              label: s.accountConnections,
              value: '$activeCons / $maxCons',
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ── Server Info card ───────────────────────────────────────────────
        _Card(
          title: 'Server Info',
          icon: Icons.dns_outlined,
          children: [
            _Row(
              label: s.accountServer,
              value: serverPort.isNotEmpty
                  ? '$serverUrl:$serverPort'
                  : serverUrl,
            ),
            _Row(label: s.accountTimezone, value: timezone),
            if (timeNow.isNotEmpty)
              _Row(label: 'Server Time', value: timeNow),
          ],
        ),

        // ── Formats card ───────────────────────────────────────────────────
        if (userInfo['allowed_output_formats'] != null) ...[
          const SizedBox(height: 16),
          _Card(
            title: 'Output Formats',
            icon: Icons.video_file_outlined,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 4, 0, 4),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final fmt
                        in (userInfo['allowed_output_formats'] as List))
                      _FormatChip(label: fmt.toString()),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  static String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.icon,
    required this.children,
  });
  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.valueColor,
    this.valueBadge = false,
  });
  final String label;
  final String value;
  final Color? valueColor;
  final bool valueBadge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: valueBadge
                ? Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (valueColor ?? AppColors.textMuted)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (valueColor ?? AppColors.textMuted)
                            .withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      value,
                      style: TextStyle(
                        color: valueColor ?? AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : Text(
                    value,
                    style: TextStyle(
                      color: valueColor ?? AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FormatChip extends StatelessWidget {
  const _FormatChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
