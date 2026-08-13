import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';

/// RSup/10e — dedicated full-screen ack confirmation (not a snackbar).
class RequestAcknowledgedScreen extends StatelessWidget {
  const RequestAcknowledgedScreen({
    required this.requestCode,
    required this.requestType,
    super.key,
  });

  final String requestCode;
  final String requestType;

  static String _typeLabel(String type, AppLocalizations l10n) {
    return switch (type) {
      'leave' => l10n.supportRequestTypeLeaveRequest,
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
      appBar: AppBar(
        title: Text(l10n.supportAcknowledgedTitle),
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
              Text(
                l10n.supportResponseAcknowledged,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.supportResponseAcknowledgedBody,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.pageBackground,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  l10n.supportCodeWithType(
                      requestCode, _typeLabel(requestType, l10n)),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.blueberry),
                  onPressed: () => context.go('/profile/support/requests'),
                  child: Text(l10n.supportBackToMyRequests),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
