import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/dashboard_providers.dart';

Future<void> showRateContractorDialog(
  BuildContext context, {
  required String incidentId,
  required String incidentTitle,
  required String contractorId,
}) {
  return showDialog(
    context: context,
    builder: (_) => _RateContractorDialog(
      incidentId: incidentId,
      incidentTitle: incidentTitle,
      contractorId: contractorId,
    ),
  );
}

class _RateContractorDialog extends ConsumerStatefulWidget {
  final String incidentId;
  final String incidentTitle;
  final String contractorId;

  const _RateContractorDialog({
    required this.incidentId,
    required this.incidentTitle,
    required this.contractorId,
  });

  @override
  ConsumerState<_RateContractorDialog> createState() =>
      _RateContractorDialogState();
}

class _RateContractorDialogState
    extends ConsumerState<_RateContractorDialog> {
  int _selectedStars = 0;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedStars == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a star rating.'),
          backgroundColor: AppTheme.darkBg,
        ),
      );
      return;
    }

    final ok = await ref.read(submitRatingProvider.notifier).submit(
          incidentId: widget.incidentId,
          contractorId: widget.contractorId,
          rating: _selectedStars,
          comment: _commentController.text.trim().isEmpty
              ? null
              : _commentController.text.trim(),
        );

    if (mounted) {
      if (ok) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rating submitted — thanks!'),
            backgroundColor: AppTheme.darkBg,
          ),
        );
      } else {
        final err = ref.read(submitRatingProvider).error;
        final msg = err.toString().contains('unique')
            ? 'You\'ve already rated this job.'
            : 'Failed to submit rating. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppTheme.darkBg),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final saveState = ref.watch(submitRatingProvider);
    final isSaving = saveState.isLoading;

    // Check if already rated
    final existingAsync =
        ref.watch(incidentRatingProvider(widget.incidentId));

    return Dialog(
      backgroundColor: AppTheme.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: existingAsync.when(
          loading: () => const SizedBox(
            height: 120,
            child: Center(
              child: CircularProgressIndicator(color: AppTheme.green),
            ),
          ),
          error: (_, __) => _buildForm(isSaving),
          data: (existing) {
            if (existing != null) {
              // Already rated — show read-only view
              return _AlreadyRatedView(
                rating: existing.rating,
                comment: existing.comment,
                onClose: () => Navigator.of(context).pop(),
              );
            }
            return _buildForm(isSaving);
          },
        ),
      ),
    );
  }

  Widget _buildForm(bool isSaving) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.contractorBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.star_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Rate Contractor',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    widget.incidentTitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Star selector
        const Text(
          'How would you rate the work?',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final starIndex = i + 1;
            return GestureDetector(
              onTap: () => setState(() => _selectedStars = starIndex),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  child: Icon(
                    starIndex <= _selectedStars
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 40,
                    color: starIndex <= _selectedStars
                        ? const Color(0xFFF59E0B)
                        : AppTheme.textMuted,
                  ),
                ),
              ),
            );
          }),
        ),
        if (_selectedStars > 0) ...[
          const SizedBox(height: 6),
          Center(
            child: Text(
              _starLabel(_selectedStars),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),

        // Comment
        TextField(
          controller: _commentController,
          decoration: const InputDecoration(
            labelText: 'Comment (optional)',
            hintText: 'Describe the work quality...',
            alignLabelWithHint: true,
          ),
          maxLines: 3,
          maxLength: 300,
        ),
        const SizedBox(height: 20),

        // Actions
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed:
                    isSaving ? null : () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textMuted,
                  side: const BorderSide(
                      color: AppTheme.border, width: 0.5),
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: isSaving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.green,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Submit',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _starLabel(int stars) {
    switch (stars) {
      case 1:
        return 'Poor';
      case 2:
        return 'Below average';
      case 3:
        return 'Good';
      case 4:
        return 'Very good';
      case 5:
        return 'Excellent';
      default:
        return '';
    }
  }
}

// ---------------------------------------------------------------------------
// Already-rated read-only view

class _AlreadyRatedView extends StatelessWidget {
  final int rating;
  final String? comment;
  final VoidCallback onClose;

  const _AlreadyRatedView({
    required this.rating,
    required this.comment,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Your Rating',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            GestureDetector(
              onTap: onClose,
              child: const Icon(Icons.close,
                  size: 20, color: AppTheme.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final starIndex = i + 1;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                starIndex <= rating
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                size: 36,
                color: starIndex <= rating
                    ? const Color(0xFFF59E0B)
                    : AppTheme.textMuted,
              ),
            );
          }),
        ),
        if (comment != null && comment!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.bgPage,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppTheme.border, width: 0.5),
            ),
            child: Text(
              comment!,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: onClose,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textMuted,
              side: const BorderSide(
                  color: AppTheme.border, width: 0.5),
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Close'),
          ),
        ),
      ],
    );
  }
}
