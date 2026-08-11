import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import 'support_providers.dart';

class RequestDetailScreen extends ConsumerStatefulWidget {
  const RequestDetailScreen({required this.requestId, super.key});

  final String requestId;

  @override
  ConsumerState<RequestDetailScreen> createState() =>
      _RequestDetailScreenState();
}

class _RequestDetailScreenState extends ConsumerState<RequestDetailScreen> {
  final _answerCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _answerCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitClarification() async {
    final answer = _answerCtrl.text.trim();
    if (answer.isEmpty) return;
    setState(() => _submitting = true);
    try {
      await ref.read(supportServiceProvider).submitClarification(
            requestId: widget.requestId,
            answer: answer,
          );
      _answerCtrl.clear();
      ref.invalidate(requestDetailProvider(widget.requestId));
      ref.invalidate(myRequestsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clarification submitted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(requestDetailProvider(widget.requestId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request detail'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (detail) {
          final needsClarify = detail.status == 'needs_clarification';
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                detail.requestCode,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${detail.requestType} · ${detail.status}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              if (detail.currentStepLabel != null) ...[
                const SizedBox(height: 4),
                Text('Current step: ${detail.currentStepLabel}'),
              ],
              const SizedBox(height: 16),
              const Text(
                'Approval progress',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ...detail.steps.map((step) {
                final status = step['status']?.toString() ?? '';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: status == 'in_progress'
                          ? AppColors.progressGreen
                          : AppColors.border,
                    ),
                    color: status == 'in_progress'
                        ? AppColors.progressGreen.withValues(alpha: 0.08)
                        : null,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${step['step_order']}. ${step['step_name']}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        status,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              if (detail.clarifications.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Clarifications',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ...detail.clarifications.map((c) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c['question']?.toString() ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (c['answer'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(c['answer'].toString()),
                          )
                        else
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text(
                              'Awaiting your response',
                              style: TextStyle(color: AppColors.underReviewAmber),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ],
              if (needsClarify) ...[
                const SizedBox(height: 16),
                const Text(
                  'Submit clarification',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _answerCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Your response',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _submitting ? null : _submitClarification,
                  child: _submitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit clarification'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
