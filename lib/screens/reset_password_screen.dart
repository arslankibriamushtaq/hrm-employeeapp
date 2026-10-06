import 'package:flutter/material.dart';

import '../session.dart';
import '../widgets/common.dart';

/// There is no "forgot password" endpoint: HR's welcome email carries a link with a
/// one-time `?token=`. The employee pastes that link (or just the token) here.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _link = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _link.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  /// Accepts either the full link or the bare token.
  String _extractToken(String input) {
    final text = input.trim();
    final uri = Uri.tryParse(text);
    final fromQuery = uri?.queryParameters['token'];
    return (fromQuery != null && fromQuery.isNotEmpty) ? fromQuery : text;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final message = await AppScope.read(context)
          .api
          .resetPassword(_extractToken(_link.text), _password.text);
      if (!mounted) return;
      showSnack(context, message);
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set your password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Paste the reset link from your welcome email, then choose a new password. '
                    'Links can be used once and expire after 7 days.'),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _link,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Reset link or token',
                    prefixIcon: Icon(Icons.link),
                  ),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Paste the link from your email' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (v) => (v ?? '').length < 8 ? 'At least 8 characters' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirm,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm new password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (v) => v != _password.text ? 'Passwords do not match' : null,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  child: _busy
                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                      : const Text('Update password'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
