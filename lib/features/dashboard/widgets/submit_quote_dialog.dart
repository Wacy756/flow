import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/dashboard_providers.dart';

Future<void> showSubmitQuoteDialog(
  BuildContext context, {
  required String incidentId,
  required String incidentTitle,
}) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _QuoteDialog(
      incidentId: incidentId,
      incidentTitle: incidentTitle,
    ),
  );
}

class _QuoteDialog extends ConsumerStatefulWidget {
  final String incidentId;
  final String incidentTitle;
  const _QuoteDialog(
      {required this.incidentId, required this.incidentTitle});

  @override
  ConsumerState<_QuoteDialog> createState() => _QuoteDialogState();
}

class _QuoteDialogState extends ConsumerState<_QuoteDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(submitQuoteProvider);
    final isLoading = state.isLoading;

    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Submit Quote'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.incidentTitle,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Quote amount (£)',
                prefixText: '£ ',
                filled: true,
                fillColor: AppTheme.background,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter an amount';
                if (double.tryParse(v.trim()) == null) {
                  return 'Invalid number';
                }
                if (double.parse(v.trim()) <= 0) return 'Must be > 0';
                return null;
              },
            ),
            if (state.hasError) ...[
              const SizedBox(height: 8),
              Text(state.error.toString(),
                  style: TextStyle(
                      color: Colors.red.shade700, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7C3AED),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Submit',
                  style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.parse(_controller.text.trim());
    final ok = await ref
        .read(submitQuoteProvider.notifier)
        .submit(widget.incidentId, amount);
    if (ok && mounted) Navigator.of(context).pop();
  }
}
