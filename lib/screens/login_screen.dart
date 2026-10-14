import 'package:flutter/material.dart';

import '../session.dart';
import '../widgets/common.dart';
import '../widgets/text_input_dialog.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await AppScope.read(context).login(_email.text, _password.text);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editServer() async {
    final session = AppScope.read(context);
    final result = await showTextInputDialog(
      context,
      title: 'Server address',
      hint: 'http://192.168.1.10:8080',
      initialText: session.baseUrl,
      confirmLabel: 'Save',
      autofocus: true,
      keyboardType: TextInputType.url,
    );
    if (result != null) {
      await session.setBaseUrl(result);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Server settings',
            icon: const Icon(Icons.dns_outlined),
            onPressed: _editServer,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Icon(Icons.badge_outlined, size: 36, color: theme.colorScheme.onPrimaryContainer),
                    ),
                    const SizedBox(height: 16),
                    Text('Welcome back',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Sign in with the account HR created for you',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        if (value.isEmpty) return 'Email is required';
                        if (!value.contains('@')) return 'Enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) => (v ?? '').isEmpty ? 'Password is required' : null,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                      child: _busy
                          ? const SizedBox(
                              height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                          : const Text('Sign in'),
                    ),
                    const SizedBox(height: 12),
                    // Password set/reset happens on the web portal only.
                    Text(
                      'New here? Set your password using the link in your welcome email, then sign in.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Server: ${AppScope.read(context).baseUrl}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
