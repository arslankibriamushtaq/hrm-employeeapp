import 'package:flutter/material.dart';

/// Single-field input dialog. Returns the entered text, or null when cancelled.
///
/// The dialog owns its controller and form key and disposes them in its own
/// State.dispose(), which only runs once the route has finished its exit animation.
/// Disposing a caller-owned controller right after `await showDialog` breaks the
/// still-animating TextField (seen as '_dependents.isEmpty' assertions).
Future<String?> showTextInputDialog(
  BuildContext context, {
  required String title,
  String? message,
  String? label,
  String? hint,
  String initialText = '',
  String confirmLabel = 'OK',
  bool destructive = false,
  bool autofocus = false,
  int maxLines = 1,
  int? maxLength,
  TextInputType? keyboardType,
  String? Function(String?)? validator,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _TextInputDialog(
      title: title,
      message: message,
      label: label,
      hint: hint,
      initialText: initialText,
      confirmLabel: confirmLabel,
      destructive: destructive,
      autofocus: autofocus,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      validator: validator,
    ),
  );
}

class _TextInputDialog extends StatefulWidget {
  const _TextInputDialog({
    required this.title,
    required this.message,
    required this.label,
    required this.hint,
    required this.initialText,
    required this.confirmLabel,
    required this.destructive,
    required this.autofocus,
    required this.maxLines,
    required this.maxLength,
    required this.keyboardType,
    required this.validator,
  });

  final String title;
  final String? message;
  final String? label;
  final String? hint;
  final String initialText;
  final String confirmLabel;
  final bool destructive;
  final bool autofocus;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final _controller = TextEditingController(text: widget.initialText);
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_formKey.currentState!.validate()) Navigator.pop(context, _controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.message != null) ...[
              Text(widget.message!),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _controller,
              maxLines: widget.maxLines,
              maxLength: widget.maxLength,
              autofocus: widget.autofocus,
              keyboardType: widget.keyboardType,
              decoration: InputDecoration(
                labelText: widget.label,
                hintText: widget.hint,
                alignLabelWithHint: widget.maxLines > 1,
              ),
              validator: widget.validator,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          style: widget.destructive
              ? FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error)
              : null,
          onPressed: _confirm,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
