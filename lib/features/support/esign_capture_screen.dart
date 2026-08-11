import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import 'support_providers.dart';
import 'widgets/signature_pad.dart';

class EsignCaptureScreen extends ConsumerStatefulWidget {
  const EsignCaptureScreen({required this.requestId, super.key});

  final String requestId;

  @override
  ConsumerState<EsignCaptureScreen> createState() => _EsignCaptureScreenState();
}

class _EsignCaptureScreenState extends ConsumerState<EsignCaptureScreen> {
  final _padController = SignaturePadController();
  final _nameCtrl = TextEditingController();
  bool _legalAccepted = false;
  bool _submitting = false;

  @override
  void dispose() {
    _padController.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_legalAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept the declaration')),
      );
      return;
    }
    if (!_padController.hasInk) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please draw your signature')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      const padSize = Size(360, 180);
      final pngBytes = await _padController.toPngBytes(size: padSize);
      if (pngBytes == null) {
        throw Exception('signature_empty');
      }
      final service = ref.read(supportServiceProvider);
      final storageKey = await service.uploadEsignSignature(
        requestId: widget.requestId,
        pngBytes: pngBytes,
      );
      await service.submitEsignature(
        requestId: widget.requestId,
        signatureStorageKey: storageKey,
        signerDisplayName: _nameCtrl.text.trim().isEmpty
            ? null
            : _nameCtrl.text.trim(),
        signerMeta: {
          'signed_via': 'mobile_app',
          'stroke_count': _padController.strokes.length,
        },
      );
      ref.invalidate(esignRequestsProvider);
      ref.invalidate(esignRequestDetailProvider(widget.requestId));
      if (!mounted) return;
      context.go('/profile/support/sign/${widget.requestId}/confirmed');
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign document'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Draw your signature below',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Container(
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
              color: Colors.white,
            ),
            clipBehavior: Clip.antiAlias,
            child: SignaturePad(controller: _padController),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _padController.clear,
              child: const Text('Clear'),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Full name (optional)',
            ),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _legalAccepted,
            onChanged: (v) => setState(() => _legalAccepted = v ?? false),
            title: const Text(
              'I confirm this is my legal signature and I agree to the terms of this document.',
              style: TextStyle(fontSize: 13),
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: _submitting ? null : _submit,
            child: Text(_submitting ? 'Submitting…' : 'Confirm signature'),
          ),
        ),
      ),
    );
  }
}
