import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';

Future<File?> showUpdateProgressDialog(
  BuildContext context, {
  required Future<File> Function(void Function(double progress) onProgress) onDownload,
}) {
  return showDialog<File>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _UpdateProgressDialog(onDownload: onDownload),
  );
}

class _UpdateProgressDialog extends StatefulWidget {
  const _UpdateProgressDialog({required this.onDownload});

  final Future<File> Function(void Function(double progress) onProgress) onDownload;

  @override
  State<_UpdateProgressDialog> createState() => _UpdateProgressDialogState();
}

class _UpdateProgressDialogState extends State<_UpdateProgressDialog> {
  double _progress = 0;
  String? _error;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
      _error = null;
      _progress = 0;
    });
    try {
      final file = await widget.onDownload((value) {
        if (!mounted) return;
        setState(() => _progress = value.clamp(0, 1));
      });
      if (!mounted) return;
      Navigator.of(context).pop(file);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _downloading = false;
      });
    }
  }

  void _close() {
    Navigator.of(context).pop<File?>(null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final percent = (_progress * 100).round();
    final hasError = _error != null;

    return AlertDialog(
      title: Text(
        hasError ? l10n.somethingWentWrong : l10n.updateDownloading(percent),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!hasError)
            LinearProgressIndicator(
              value: _progress > 0 ? _progress : null,
              color: AppColors.accentOrange,
            ),
          if (_error != null) ...[
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
      actions: hasError
          ? [
              TextButton(
                onPressed: _close,
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: _downloading ? null : _start,
                child: Text(l10n.updateDownload),
              ),
            ]
          : null,
    );
  }
}
