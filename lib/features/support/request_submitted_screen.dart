import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';

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

  static String _typeLabel(String? type) {
    return switch (type) {
      'leave' => 'Leave',
      'sick_leave' => 'Sick & accident leave',
      'asset' => 'Asset request',
      'fuel' => 'Fuel reimbursement',
      'document' => 'Document request',
      'complaint' => 'Complaint',
      'salary_justification' => 'Salary justification',
      'loan' => 'Loan request',
      _ => 'Request',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Submitted')),
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
            const Text(
              'Request submitted',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'We have received your request and will review it shortly. You can track its status anytime.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
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
                  _row('Request ID', requestCode),
                  const Divider(height: 20),
                  _row('Type', _typeLabel(requestType)),
                  const Divider(height: 20),
                  Row(
                    children: [
                      const Text('Status', style: TextStyle(color: AppColors.textSecondary)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.underReviewAmber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Pending',
                          style: TextStyle(
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
                    context.go('/profile/support/requests/$requestId');
                  } else {
                    context.go('/profile/support/requests');
                  }
                },
                child: const Text('Track request'),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => context.go('/profile/support'),
              child: const Text('Back to support'),
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
