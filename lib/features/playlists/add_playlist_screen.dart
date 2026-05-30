import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/storage/storage_service.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/playlist.dart';
import '../../services/xtream_service.dart';

class AddPlaylistScreen extends ConsumerStatefulWidget {
  const AddPlaylistScreen({super.key});

  @override
  ConsumerState<AddPlaylistScreen> createState() => _AddPlaylistScreenState();
}

class _AddPlaylistScreenState extends ConsumerState<AddPlaylistScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _serverCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  // Focus nodes so the remote / keyboard "next" advances field → field
  // (Android TV D-pad can't otherwise move between text fields reliably).
  final _nameNode = FocusNode();
  final _serverNode = FocusNode();
  final _usernameNode = FocusNode();
  final _passwordNode = FocusNode();

  bool _loading = false;
  String? _error;

  // Shown under the spinner when the server takes more than 5 seconds
  String _hint = '';
  Timer? _hintTimer;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _serverCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _nameNode.dispose();
    _serverNode.dispose();
    _usernameNode.dispose();
    _passwordNode.dispose();
    _hintTimer?.cancel();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; _hint = ''; });

    // Show a "server is slow" hint after 5 s so the user doesn't panic.
    _hintTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _loading) {
        setState(() => _hint = 'Server is responding slowly — please wait…');
      }
    });
    // If it's still going after 20 s, reassure them retries are happening.
    Timer(const Duration(seconds: 20), () {
      if (mounted && _loading) {
        setState(() => _hint = 'Retrying connection (may take up to 60 s)…');
      }
    });

    try {
      final service = ref.read(xtreamServiceProvider);
      final result = await service.authenticate(
        _serverCtrl.text.trim(),
        _usernameCtrl.text.trim(),
        _passwordCtrl.text.trim(),
      );

      final userInfo = result['user_info'] as Map<String, dynamic>? ?? {};
      final expiryTs = int.tryParse(userInfo['exp_date']?.toString() ?? '');
      final expiry = expiryTs != null
          ? DateTime.fromMillisecondsSinceEpoch(expiryTs * 1000)
          : null;

      final playlist = Playlist(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameCtrl.text.trim(),
        serverUrl: _serverCtrl.text.trim(),
        username: _usernameCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
        addedAt: DateTime.now(),
        expiryDate: expiry,
      );

      await StorageService.savePlaylist(playlist);
      await StorageService.setActivePlaylistId(playlist.id);

      if (mounted) context.pop();
    } on DioException catch (e) {
      setState(() => _error = _dioMessage(e));
    } catch (e) {
      setState(() => _error = 'Unexpected error: $e');
    } finally {
      _hintTimer?.cancel();
      if (mounted) setState(() { _loading = false; _hint = ''; });
    }
  }

  // ── Human-readable error messages ─────────────────────────────────────────

  static String _dioMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return 'Could not reach the server after 60 s (connection timeout).\n'
            'The server may be offline or the URL is wrong.';
      case DioExceptionType.receiveTimeout:
        return 'Server connected but did not respond in time.\n'
            'It may be overloaded — try again in a few minutes.';
      case DioExceptionType.sendTimeout:
        return 'Request could not be sent (send timeout).\n'
            'Check your internet connection.';
      case DioExceptionType.connectionError:
        return 'Network error: could not connect to the server.\n'
            'Check the URL (include http:// and port) and your internet.';
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode;
        if (code == 401 || code == 403) {
          return 'Wrong username or password (HTTP $code).';
        }
        return 'Server returned an error (HTTP $code).\n'
            'The URL may be incorrect, or the server is down.';
      case DioExceptionType.badCertificate:
        return 'SSL certificate error — try using http:// instead of https://.';
      case DioExceptionType.cancel:
        return 'Request was cancelled.';
      default:
        return 'Connection failed: ${e.message}';
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Playlist')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildField(_nameCtrl, 'Playlist Name', Icons.label_outline,
                  hint: 'My IPTV',
                  focusNode: _nameNode,
                  autofocus: true,
                  onSubmitted: () => _serverNode.requestFocus()),
              const SizedBox(height: 14),
              _buildField(_serverCtrl, 'Server URL', Icons.dns_outlined,
                  hint: 'http://yourserver.com:8080',
                  keyboardType: TextInputType.url,
                  focusNode: _serverNode,
                  onSubmitted: () => _usernameNode.requestFocus()),
              const SizedBox(height: 14),
              _buildField(_usernameCtrl, 'Username', Icons.person_outline,
                  focusNode: _usernameNode,
                  onSubmitted: () => _passwordNode.requestFocus()),
              const SizedBox(height: 14),
              _buildField(_passwordCtrl, 'Password', Icons.lock_outline,
                  obscure: true,
                  focusNode: _passwordNode,
                  textInputAction: TextInputAction.done,
                  onSubmitted: () => _submit()),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.liveRed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_error!,
                      style: const TextStyle(
                          color: AppColors.liveRed, fontSize: 13, height: 1.5)),
                ),
              ],
              const SizedBox(height: 28),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text('Connect & Save'),
                ),
              ),
              // Slow-server hint — appears after 5 s, disappears on completion.
              if (_loading && _hint.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  _hint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    String? hint,
    bool obscure = false,
    TextInputType? keyboardType,
    FocusNode? focusNode,
    bool autofocus = false,
    TextInputAction textInputAction = TextInputAction.next,
    VoidCallback? onSubmitted,
  }) {
    return TextFormField(
      controller: ctrl,
      focusNode: focusNode,
      autofocus: autofocus,
      obscureText: obscure,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted: (_) => onSubmitted?.call(),
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.textMuted),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
      ),
      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
    );
  }
}
