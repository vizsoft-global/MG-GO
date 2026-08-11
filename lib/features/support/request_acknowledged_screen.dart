import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';

/// RSup/10e — dedicated full-screen ack confirmation (not a snackbar).
class RequestAcknowledgedScreen extends StatelessWidget {
  const RequestAcknowledgedScreen({
    required this.requestCode,
    required this.requestType,
    super.key,
  });

  final String requestCode;
  final String requestType;

  static String _typeLabel(String type) {
    return switch (type) {
      'leave' => 'Leave request',
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
      appBar: AppBar(
        title: const Text('Acknowledged'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/profile/support/requests'),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.progressGreen.withValues(alpha: 0.15),
                ),
                child: const Icon(Icons.check_rounded, size: 48, color: AppColors.progressGreen),
              ),
              const SizedBox(height: 20),
              const Text(
                'Response acknowledged',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                "Thanks. We've let the admin know you've seen and accepted their response.",
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.pageBackground,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$requestCode · ${_typeLabel(requestType)}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.blueberry),
                  onPressed: () => context.go('/profile/support/requests'),
                  child: const Text('Back to my requests'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
