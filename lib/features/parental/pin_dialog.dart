import 'package:flutter/material.dart';
import '../../core/storage/storage_service.dart';
import '../../core/theme/app_theme.dart';

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
    if (key == '⌫') {
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
            _PinDots(length: _entered.length, error: _error),
            if (_error) ...[
              const SizedBox(height: 8),
              const Text('Incorrect PIN',
                  style: TextStyle(color: AppColors.liveRed, fontSize: 12)),
            ],
            const SizedBox(height: 24),
            _NumPad(onTap: _tap),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _PinDots extends StatelessWidget {
  const _PinDots({required this.length, required this.error});
  final int length;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        final filled = i < length;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: error
                ? AppColors.liveRed
                : filled
                    ? AppColors.primary
                    : Colors.transparent,
            border: Border.all(
              color: error
                  ? AppColors.liveRed
                  : filled
                      ? AppColors.primary
                      : AppColors.textMuted,
              width: 2,
            ),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _NumPad extends StatelessWidget {
  const _NumPad({required this.onTap});
  final ValueChanged<String> onTap;

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['', '0', '⌫'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _rows.map((row) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: row.map((k) {
            if (k.isEmpty) return const SizedBox(width: 68, height: 56);
            return GestureDetector(
              onTap: () => onTap(k),
              child: Container(
                width: 68,
                height: 56,
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: k == '⌫'
                      ? const Icon(Icons.backspace_outlined,
                          color: AppColors.textSecondary, size: 20)
                      : Text(k,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w600)),
                ),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}
