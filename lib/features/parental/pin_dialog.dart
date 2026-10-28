import 'package:flutter/material.dart';
import '../../core/storage/storage_service.dart';
import '../../core/theme/app_theme.dart';
import 'pin_pad.dart';

/// Shows a PIN-entry dialog. Returns true if the correct PIN is entered,
/// false if the user cancels.
Future<bool> showPinDialog(
  BuildContext context, {
  String title = 'Enter PIN',
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PinDialog(title: title),
  );
  return result ?? false;
}

// ─────────────────────────────────────────────────────────────────────────────

class _PinDialog extends StatefulWidget {
  const _PinDialog({required this.title});
  final String title;

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  String _entered = '';
  bool _error = false;

  void _tap(String key) {
    if (key == pinBackspace) {
      if (_entered.isEmpty) return;
      setState(() {
        _entered = _entered.substring(0, _entered.length - 1);
        _error = false;
      });
      return;
    }
    if (_entered.length >= 4) return;
    setState(() {
      _entered += key;
      _error = false;
    });
    if (_entered.length == 4) _verify();
  }

  void _verify() {
    if (StorageService.parentalPin == _entered) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _entered = '';
        _error = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: PinHardwareKeys(
        onKey: _tap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, color: AppColors.primary, size: 32),
              const SizedBox(height: 12),
              Text(widget.title,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 28),
              PinDots(length: _entered.length, error: _error),
              if (_error) ...[
                const SizedBox(height: 8),
                const Text('Incorrect PIN',
                    style: TextStyle(color: AppColors.liveRed, fontSize: 12)),
              ],
              const SizedBox(height: 24),
              PinNumPad(onKey: _tap),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
