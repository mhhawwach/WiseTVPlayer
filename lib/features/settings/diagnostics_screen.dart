import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/diagnostics/crash_reporter.dart';
import '../../core/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Diagnostics — device info + recent crash log (copyable).
// ─────────────────────────────────────────────────────────────────────────────

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  String _deviceInfo = 'Loading…';
  List<CrashEntry> _crashes = [];

  @override
  void initState() {
    super.initState();
    _crashes = CrashReporter.recent();
    _loadDeviceInfo();
  }

  Future<void> _loadDeviceInfo() async {
    final buf = StringBuffer();
    try {
      final pkg = await PackageInfo.fromPlatform();
      buf.writeln('App: ${pkg.appName} ${pkg.version}+${pkg.buildNumber}');

      final plugin = DeviceInfoPlugin();
      final android = await plugin.androidInfo;
      buf
        ..writeln('Device: ${android.manufacturer} ${android.model}')
        ..writeln('Product: ${android.product}')
        ..writeln('Android: ${android.version.release} (SDK ${android.version.sdkInt})')
        ..writeln('ABI: ${android.supportedAbis.join(", ")}');
    } catch (e) {
      buf.writeln('Device info unavailable: $e');
    }
    if (mounted) setState(() => _deviceInfo = buf.toString().trim());
  }

  String _buildReport() {
    final buf = StringBuffer()
      ..writeln('── WiseVodPlayer Diagnostics ──')
      ..writeln(_deviceInfo)
      ..writeln('')
      ..writeln('Crashes: ${_crashes.length}')
      ..writeln('────────────────────────────');
    for (final c in _crashes) {
      buf
        ..writeln(c.formatted)
        ..writeln('────────────────────────────');
    }
    return buf.toString();
  }

  Future<void> _copyAll() async {
    await Clipboard.setData(ClipboardData(text: _buildReport()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Diagnostics copied to clipboard')),
      );
    }
  }

  Future<void> _clearCrashes() async {
    await CrashReporter.clear();
    if (mounted) setState(() => _crashes = []);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all_rounded),
            tooltip: 'Copy report',
            onPressed: _copyAll,
          ),
          if (_crashes.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear crashes',
              onPressed: _clearCrashes,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Device info card ──────────────────────────────────────────────
          _Card(
            title: 'Device',
            icon: Icons.phone_android_rounded,
            child: SelectableText(
              _deviceInfo,
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.5),
            ),
          ),
          const SizedBox(height: 16),

          // ── Crash log ─────────────────────────────────────────────────────
          Row(
            children: [
              Icon(Icons.bug_report_outlined,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'CRASH LOG (${_crashes.length})',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_crashes.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32),
              alignment: Alignment.center,
              child: const Column(
                children: [
                  Icon(Icons.check_circle_outline_rounded,
                      color: AppColors.textMuted, size: 40),
                  SizedBox(height: 10),
                  Text('No crashes recorded',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 14)),
                ],
              ),
            )
          else
            ..._crashes.map((c) => _CrashTile(entry: c)),
        ],
      ),
    );
  }
}

// ── Crash tile ──────────────────────────────────────────────────────────────

class _CrashTile extends StatelessWidget {
  const _CrashTile({required this.entry});
  final CrashEntry entry;

  @override
  Widget build(BuildContext context) {
    final t = entry.time.toLocal().toString().split('.').first;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding:
              const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.error_outline_rounded,
                color: Colors.red, size: 18),
          ),
          title: Text(
            entry.error,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            '$t · ${entry.source}',
            style: const TextStyle(
                color: AppColors.textMuted, fontSize: 11),
          ),
          children: [
            SelectableText(
              entry.stack.isEmpty ? '(no stack trace)' : entry.stack,
              style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontFamily: 'monospace',
                  height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Card ──────────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.icon, required this.child});
  final String title;
  final IconData icon;
  final Widget child;

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
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
