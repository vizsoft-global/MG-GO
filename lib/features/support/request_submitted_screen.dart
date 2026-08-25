import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';

class RequestSubmittedScreen extends StatelessWidget {
  const RequestSubmittedScreen({
    required this.requestCode,
    this.requestId,
    this.requestType,
    super.key,
  });

  final String requestCode;
  final String? requestId;
  final String? requestType;

  static String _typeLabel(String? type, AppLocalizations l10n) {
    return switch (type) {
      'leave' => l10n.supportRequestTypeLeave,
      'sick_leave' => l10n.supportRequestTypeSickLeave,
      'asset' => l10n.supportRequestTypeAsset,
      'fuel' => l10n.supportRequestTypeFuel,
      'document' => l10n.supportRequestTypeDocument,
      'complaint' => l10n.supportRequestTypeComplaint,
      'salary_justification' => l10n.supportRequestTypeSalaryJustification,
      'loan' => l10n.supportRequestTypeLoanRequest,
      _ => l10n.supportRequestTypeGeneric,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.supportSubmittedTitle)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.progressGreen.withValues(alpha: 0.15),
              ),
              child: const Icon(Icons.check_rounded, size: 48, color: AppColors.progressGreen),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.supportRequestSubmitted,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.supportRequestSubmittedBody,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _row(l10n.supportFieldRequestId, requestCode),
                  const Divider(height: 20),
                  _row(l10n.supportFieldType, _typeLabel(requestType, l10n)),
                  const Divider(height: 20),
                  Row(
                    children: [
                      Text(l10n.status,
                          style: const TextStyle(
                              color: AppColors.textSecondary)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.underReviewAmber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          // driver_create_request inserts the row as 'submitted', so the
                          // confirmation screen has to say the same word the list will.
                          l10n.submitted,
                          style: const TextStyle(
                            color: AppColors.underReviewAmber,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.accentOrange),
                onPressed: () {
                  if (requestId != null) {
                    context.push('/profile/support/requests/$requestId');
                  } else {
                    context.go('/profile/support/requests');
                  }
                },
                child: Text(l10n.supportTrackRequest),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => context.go('/profile/support'),
              child: Text(l10n.supportBackToSupport),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _row(String label, String value) {
    return Row(
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}
