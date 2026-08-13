import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import 'request_type_definition.dart';
import 'support_providers.dart';

/// Renders a request form from `request_field_definitions`.
///
/// Built-in types keep their ARB titles and option labels so the Figma wording
/// survives; everything else uses the server-authored copy.
class DynamicRequestFormScreen extends ConsumerStatefulWidget {
  const DynamicRequestFormScreen({required this.type, super.key});

  final String type;

  @override
  ConsumerState<DynamicRequestFormScreen> createState() =>
      _DynamicRequestFormScreenState();
}

class _DynamicRequestFormScreenState
    extends ConsumerState<DynamicRequestFormScreen> {
  final _controllers = <String, TextEditingController>{};
  final _values = <String, dynamic>{};
  final List<({String name, Uint8List bytes, String contentType})> _files = [];
  bool _submitting = false;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(String key) =>
      _controllers.putIfAbsent(key, TextEditingController.new);

  Future<void> _pickDate(String key, {bool monthOnly = false}) async {
    final now = DateTime.now();
    final current = _values[key] as DateTime?;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked == null) return;
    setState(() => _values[key] = monthOnly
        ? DateTime(picked.year, picked.month)
        : picked);
  }

  Future<void> _pickFile() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _files.add((name: picked.name, bytes: bytes, contentType: 'image/jpeg'));
    });
  }

  Future<List<Map<String, dynamic>>> _uploadFiles() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) throw Exception('not_authenticated');
    final out = <Map<String, dynamic>>[];
    for (final file in _files) {
      final key = '$uid/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      await Supabase.instance.client.storage
          .from('request-attachments')
          .uploadBinary(
            key,
            file.bytes,
            fileOptions:
                FileOptions(contentType: file.contentType, upsert: false),
          );
      out.add({
        'storage_key': key,
        'file_name': file.name,
        'content_type': file.contentType,
        'byte_size': file.bytes.length,
      });
    }
    return out;
  }

  static String _isoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _isoMonth(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  /// The raw value a field currently holds, normalised to what goes on the wire.
  dynamic _wireValue(RequestFieldDefinition field) {
    switch (field.kind) {
      case 'text':
      case 'textarea':
      case 'number':
        final text = _controllerFor(field.fieldKey).text.trim();
        if (text.isEmpty) return null;
        return field.kind == 'number' ? double.tryParse(text) : text;
      case 'date':
        final d = _values[field.fieldKey] as DateTime?;
        return d == null ? null : _isoDate(d);
      case 'month':
        final d = _values[field.fieldKey] as DateTime?;
        return d == null ? null : _isoMonth(d);
      case 'multiselect':
        final list = (_values[field.fieldKey] as List<String>?) ?? const [];
        return list.isEmpty ? null : list;
      case 'checkbox':
        return _values[field.fieldKey] as bool? ?? false;
      default:
        return _values[field.fieldKey];
    }
  }

  bool _isEmpty(RequestFieldDefinition field, dynamic value) {
    // An unticked required checkbox is a declaration the rider has not accepted.
    if (field.kind == 'checkbox') return value != true;
    if (value == null) return true;
    if (value is String) return value.trim().isEmpty;
    if (value is List) return value.isEmpty;
    return false;
  }

  Future<void> _submit(
    RequestTypeDefinition def,
    List<RequestFieldDefinition> fields,
  ) async {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    setState(() => _submitting = true);
    try {
      final payload = <String, dynamic>{};
      double? amount;
      DateTime? start;
      DateTime? end;
      String? details;
      String? severity;

      for (final field in fields) {
        if (field.kind == 'file' || field.target == 'attachments') continue;
        final value = _wireValue(field);

        if (field.isRequired && _isEmpty(field, value)) {
          throw Exception(
            l10n.supportFieldRequiredNamed(field.label(locale)),
          );
        }
        if (_isEmpty(field, value) && field.kind != 'checkbox') continue;

        switch (field.target) {
          case 'amount_kwd':
            amount = value is num ? value.toDouble() : double.tryParse('$value');
          case 'start_date':
            start = _values[field.fieldKey] as DateTime?;
          case 'end_date':
            end = _values[field.fieldKey] as DateTime?;
          case 'details':
            details = '$value';
          case 'severity':
            severity = '$value'.toLowerCase();
          default:
            payload[field.fieldKey] = value;
        }
      }

      if (def.dateRangeRequired &&
          (start == null || end == null || end.isBefore(start))) {
        throw Exception(l10n.supportErrorLeaveTypeDatesRequired);
      }
      if (_files.length < def.minAttachments) {
        throw Exception(
          l10n.supportErrorAttachmentsMin(def.minAttachments),
        );
      }

      final attachments =
          _files.isEmpty ? <Map<String, dynamic>>[] : await _uploadFiles();

      final created = await ref.read(supportServiceProvider).createRequest(
            type: widget.type,
            payload: payload,
            attachments: attachments,
            amountKwd: amount,
            startDate: start,
            endDate: end,
            details: details,
            severity: severity,
          );

      ref.invalidate(myRequestsProvider);
      if (!mounted) return;
      context.pushReplacement(
        '/profile/support/submitted?code=${Uri.encodeComponent(created.requestCode)}&id=${created.id}&type=${widget.type}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final typesAsync = ref.watch(requestTypesProvider);
    final fieldsAsync = ref.watch(requestFieldsProvider(widget.type));

    final def = typesAsync.asData?.value
        .where((t) => t.key == widget.type)
        .firstOrNull;

    final title = builtInRequestFormTitle(l10n, widget.type) ??
        (def == null
            ? l10n.supportFormTitleNew
            : def.label(Localizations.localeOf(context)));

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: typesAsync.isLoading || fieldsAsync.isLoading
          ? const Center(child: CircularProgressIndicator())
          : def == null
              ? _Message(l10n.supportRequestTypeUnknown)
              : fieldsAsync.hasError
                  ? _Message('${fieldsAsync.error}')
                  : _body(def, fieldsAsync.asData?.value ?? const []),
      bottomNavigationBar: def == null
          ? null
          : _submitBar(def, fieldsAsync.asData?.value ?? const []),
    );
  }

  Widget _body(RequestTypeDefinition def, List<RequestFieldDefinition> fields) {
    final l10n = context.l10n;
    if (fields.isEmpty) {
      return _Message(l10n.supportRequestTypeNoFields);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        for (final field in fields) ...[
          _field(field),
          const SizedBox(height: 12),
        ],
        if (def.minAttachments > 0 &&
            !fields.any((f) => f.kind == 'file' || f.target == 'attachments'))
          _uploadButton(required: true),
      ],
    );
  }

  Widget _field(RequestFieldDefinition field) {
    final locale = Localizations.localeOf(context);
    final label = field.isRequired
        ? '${field.label(locale)} *'
        : field.label(locale);
    final help = field.help(locale);

    Widget control;
    switch (field.kind) {
      case 'textarea':
        control = TextField(
          controller: _controllerFor(field.fieldKey),
          maxLines: 4,
          decoration: InputDecoration(labelText: label, helperText: help),
        );
      case 'number':
        control = TextField(
          controller: _controllerFor(field.fieldKey),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label, helperText: help),
        );
      case 'date':
      case 'month':
        final value = _values[field.fieldKey] as DateTime?;
        control = ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          subtitle: Text(
            value == null
                ? context.l10n.selectDate
                : field.kind == 'month'
                    ? _isoMonth(value)
                    : _isoDate(value),
          ),
          trailing: const Icon(Icons.calendar_today_outlined),
          onTap: () =>
              _pickDate(field.fieldKey, monthOnly: field.kind == 'month'),
        );
      case 'select':
        control = _selectField(field, label, help);
      case 'multiselect':
        control = _multiSelectField(field, label, help);
      case 'checkbox':
        control = CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _values[field.fieldKey] as bool? ?? false,
          onChanged: (v) =>
              setState(() => _values[field.fieldKey] = v ?? false),
          title: Text(label, style: const TextStyle(fontSize: 13)),
          subtitle: help == null ? null : Text(help),
          controlAffinity: ListTileControlAffinity.leading,
        );
      case 'file':
        control = _uploadButton(required: field.isRequired);
      default:
        control = TextField(
          controller: _controllerFor(field.fieldKey),
          decoration: InputDecoration(labelText: label, helperText: help),
        );
    }
    return control;
  }

  /// Static [RequestFieldDefinition.options], or the shared DB-backed lists an
  /// admin can point a field at.
  List<({String value, String label})>? _optionsFor(
      RequestFieldDefinition field) {
    switch (field.optionsSource) {
      case 'loan_tenure_options':
        final data = ref.watch(loanTenureOptionsProvider).asData?.value;
        if (data == null) return null;
        return data
            .map((o) => (value: '${o.months}', label: o.label))
            .toList();
      case 'complaint_categories':
        final data = ref.watch(complaintCategoriesProvider).asData?.value;
        if (data == null) return null;
        final locale = Localizations.localeOf(context);
        return data
            .map((c) => (value: c.key, label: c.label(locale)))
            .toList();
      default:
        return field.options
            .map((o) => (
                  value: o,
                  label: builtInOptionLabel(context.l10n, o),
                ))
            .toList();
    }
  }

  Widget _selectField(
      RequestFieldDefinition field, String label, String? help) {
    final options = _optionsFor(field);
    if (options == null) return const LinearProgressIndicator();
    if (options.isEmpty) {
      return Text(
        context.l10n.supportTemporarilyUnavailable,
        style: const TextStyle(color: AppColors.underReviewAmber),
      );
    }
    return DropdownButtonFormField<String>(
      initialValue: _values[field.fieldKey] as String?,
      decoration: InputDecoration(labelText: label, helperText: help),
      items: options
          .map((o) => DropdownMenuItem(value: o.value, child: Text(o.label)))
          .toList(),
      onChanged: (v) => setState(() => _values[field.fieldKey] = v),
    );
  }

  Widget _multiSelectField(
      RequestFieldDefinition field, String label, String? help) {
    final options = _optionsFor(field);
    if (options == null) return const LinearProgressIndicator();
    if (options.isEmpty) {
      return Text(
        context.l10n.supportTemporarilyUnavailable,
        style: const TextStyle(color: AppColors.underReviewAmber),
      );
    }
    final selected = (_values[field.fieldKey] as List<String>?) ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((o) {
            final on = selected.contains(o.value);
            return FilterChip(
              label: Text(o.label),
              selected: on,
              onSelected: (_) {
                final next = List<String>.from(selected);
                if (on) {
                  next.remove(o.value);
                } else {
                  next.add(o.value);
                }
                setState(() => _values[field.fieldKey] = next);
              },
            );
          }).toList(),
        ),
        if (help != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              help,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
      ],
    );
  }

  Widget _uploadButton({required bool required}) {
    final l10n = context.l10n;
    return OutlinedButton.icon(
      onPressed: _pickFile,
      icon: const Icon(Icons.upload_file),
      label: Text(
        _files.isEmpty
            ? (required
                ? l10n.supportAttachmentRequired
                : l10n.supportAttachmentOptional)
            : l10n.supportFilesSelected(_files.length),
      ),
    );
  }

  Widget _submitBar(
      RequestTypeDefinition def, List<RequestFieldDefinition> fields) {
    final l10n = context.l10n;
    // Same rule the loan and complaint forms use: an option list the admin has
    // not filled in yet blocks the whole type rather than sending a value the
    // server will reject.
    final blocked = fields.any((f) {
      if (f.optionsSource == null) return false;
      return _optionsFor(f)?.isEmpty ?? true;
    });
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton(
          onPressed: (_submitting || blocked || fields.isEmpty)
              ? null
              : () => _submit(def, fields),
          child: _submitting
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  blocked
                      ? l10n.supportTemporarilyUnavailable
                      : l10n.supportSubmitRequest,
                ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
