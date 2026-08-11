import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RequestSubmittedScreen extends StatelessWidget {
  const RequestSubmittedScreen({
    required this.requestCode,
    this.requestId,
    super.key,
  });

  final String requestCode;
  final String? requestId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Submitted')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            const Text(
              'Request submitted',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              requestCode,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                if (requestId != null) {
                  context.go('/profile/support/requests/$requestId');
                } else {
                  context.go('/profile/support/requests');
                }
              },
              child: const Text('View request'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.go('/profile/support'),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
