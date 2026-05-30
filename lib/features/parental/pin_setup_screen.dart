import 'package:flutter/material.dart';
import '../../core/storage/storage_service.dart';
import '../../core/theme/app_theme.dart';
import 'pin_dialog.dart';

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final bool _hasPin = StorageService.hasParentalPin;
  // 'idle' → 'entering' → 'confirming'
  String _phase = 'idle';
  String _pin = '';
  String _confirm = '';
  bool _error = false;
  String _errorMsg = '';

  // ── State machine ──────────────────────────────────────────────────────────

  void _start() => setState(() => _phase = 'entering');

  void _tap(String key) {
    if (key == '⌫') {
      _backspace();
      return;
    }
    if (_phase == 'entering') {
      if (_pin.length >= 4) return;
      setState(() {
        _pin += key;
        _error = false;
      });
      if (_pin.length == 4) setState(() => _phase = 'confirming');
    } else if (_phase == 'confirming') {
      if (_confirm.length >= 4) return;
      setState(() {
        _confirm += key;
        _error = false;
      });
      if (_confirm.length == 4) _finalize();
    }
  }

  void _backspace() {
    setState(() {
      _error = false;
      if (_phase == 'confirming') {
        if (_confirm.isNotEmpty) {
          _confirm = _confirm.substring(0, _confirm.length - 1);
        }
      } else {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
      }
    });
  }

  void _finalize() {
    if (_pin == _confirm) {
      StorageService.setParentalPin(_pin);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Parental PIN enabled')));
      Navigator.of(context).pop();
    } else {
      setState(() {
        _confirm = '';
        _error = true;
        _errorMsg = "PINs don't match — try again";
      });
    }
  }

  Future<void> _disablePin() async {
    final ok = await showPinDialog(context, title: 'Enter current PIN');
    if (!ok || !mounted) return;
    await StorageService.clearParentalPin();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Parental PIN removed')));
      Navigator.of(context).pop();
    }
  }

  Future<void> _changePin() async {
    final ok = await showPinDialog(context, title: 'Enter current PIN');
    if (!ok || !mounted) return;
    setState(() {
      _phase = 'entering';
      _pin = '';
      _confirm = '';
      _error = false;
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parental Controls')),
      body: _phase == 'idle' ? _buildIdleView() : _buildPinEntry(),
    );
  }

  Widget _buildIdleView() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        ListTile(
          leading: Icon(
            _hasPin ? Icons.lock : Icons.lock_open,
            color: _hasPin ? AppColors.primary : AppColors.textSecondary,
          ),
          title: Text(_hasPin ? 'PIN is enabled' : 'PIN is disabled'),
          subtitle: Text(
            _hasPin
                ? 'Locked categories require this PIN to access'
                : 'Enable to protect adult or locked categories',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ),
        const Divider(),
        if (!_hasPin)
          ListTile(
            leading: const Icon(Icons.add_moderator_outlined),
            title: const Text('Set PIN'),
            onTap: _start,
          ),
        if (_hasPin) ...[
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Change PIN'),
            onTap: _changePin,
          ),
          ListTile(
            leading: const Icon(Icons.no_encryption_outlined,
                color: AppColors.liveRed),
            title: const Text('Remove PIN',
                style: TextStyle(color: AppColors.liveRed)),
            onTap: _disablePin,
          ),
        ],
        const SizedBox(height: 24),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'When a PIN is set you can lock individual categories from their '
            'context menu. Locked categories will require this PIN before opening.',
            style: TextStyle(
                color: AppColors.textMuted, fontSize: 12, height: 1.5),
          ),
        ),
      ],
    );
  }

  Widget _buildPinEntry() {
    final current = _phase == 'confirming' ? _confirm : _pin;
    final title = _phase == 'confirming' ? 'Confirm PIN' : 'Enter new PIN';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, color: AppColors.primary, size: 40),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 28),
            _PinDotsRow(length: current.length, error: _error),
            if (_error) ...[
              const SizedBox(height: 8),
              Text(_errorMsg,
                  style: const TextStyle(
                      color: AppColors.liveRed, fontSize: 12)),
            ],
            const SizedBox(height: 28),
            _NumPadWidget(onTap: _tap),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _PinDotsRow extends StatelessWidget {
  const _PinDotsRow({required this.length, required this.error});
  final int length;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        final filled = i < length;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(horizontal: 12),
          width: 18,
          height: 18,
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

class _NumPadWidget extends StatelessWidget {
  const _NumPadWidget({required this.onTap});
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
            if (k.isEmpty) return const SizedBox(width: 76, height: 64);
            return GestureDetector(
              onTap: () => onTap(k),
              child: Container(
                width: 76,
                height: 64,
                margin: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: k == '⌫'
                      ? const Icon(Icons.backspace_outlined,
                          color: AppColors.textSecondary, size: 22)
                      : Text(k,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 22,
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
