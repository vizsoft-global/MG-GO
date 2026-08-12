import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import 'support_models.dart';
import 'support_providers.dart';

class RequestFormScreen extends ConsumerStatefulWidget {
  const RequestFormScreen({required this.type, super.key});

  final String type;

  @override
  ConsumerState<RequestFormScreen> createState() => _RequestFormScreenState();
}

class _RequestFormScreenState extends ConsumerState<RequestFormScreen> {
  final _commentCtrl = TextEditingController();
  final _justificationCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _expectedCtrl = TextEditingController();
  final _receivedCtrl = TextEditingController();
  final _distanceCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');

  String? _chip;
  String? _size;
  String? _mode;
  String? _assetStatus;
  String? _language;
  String? _deliveryMethod;
  String? _severity;
  String? _categoryKey;
  int? _tenureMonths;
  DateTime? _from;
  DateTime? _to;
  DateTime? _neededBy;
  DateTime? _salaryMonth;
  bool _declaration = false;
  bool _submitting = false;
  final List<({String name, Uint8List bytes, String contentType})> _files = [];

  @override
  void dispose() {
    _commentCtrl.dispose();
    _justificationCtrl.dispose();
    _subjectCtrl.dispose();
    _descriptionCtrl.dispose();
    _reasonCtrl.dispose();
    _amountCtrl.dispose();
    _expectedCtrl.dispose();
    _receivedCtrl.dispose();
    _distanceCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  String get _title {
    final l10n = context.l10n;
    switch (widget.type) {
      case 'leave':
        return l10n.supportRequestTypeLeaveRequest;
      case 'sick_leave':
        return l10n.supportFormTitleSickLeave;
      case 'loan':
        return l10n.supportFormTitleLoan;
      case 'asset':
        return l10n.supportRequestTypeAsset;
      case 'fuel':
        return l10n.supportFormTitleFuel;
      case 'document':
        return l10n.supportRequestTypeDocument;
      case 'complaint':
        return l10n.supportRequestTypeComplaint;
      case 'salary_justification':
        return l10n.supportRequestTypeSalaryJustification;
      default:
        return l10n.supportFormTitleNew;
    }
  }

  /// Chip/segment values are sent to the server verbatim (`payload.leave_type`,
  /// `asset_type`, `severity`, …), so only the visible label is translated.
  String _optionLabel(String value) {
    final l10n = context.l10n;
    return switch (value) {
      'Annual' => l10n.supportLeaveTypeAnnual,
      'Emergency' => l10n.supportLeaveTypeEmergency,
      'Accident' => l10n.supportLeaveTypeAccident,
      'Unpaid Leave' => l10n.supportLeaveTypeUnpaid,
      'Sick leave' => l10n.supportSickTypeSickLeave,
      'Injury' => l10n.supportSickTypeInjury,
      'Other' => l10n.supportOptionOther,
      'SIM card' => l10n.supportAssetSimCard,
      'Fuel card' => l10n.supportAssetFuelCard,
      'Fuel limit change' => l10n.supportAssetFuelLimitChange,
      'Raincoat' => l10n.supportAssetRaincoat,
      'Delivery bag' => l10n.supportAssetDeliveryBag,
      'Reflective vest' => l10n.supportAssetReflectiveVest,
      'Winter jacket' => l10n.supportAssetWinterJacket,
      'Delivery attire' => l10n.supportAssetDeliveryAttire,
      'Delivery pants' => l10n.supportAssetDeliveryPants,
      'New bike' => l10n.supportAssetNewBike,
      'Helmet' => l10n.supportAssetHelmet,
      'Delivery box' => l10n.supportAssetDeliveryBox,
      'Fuel chip' => l10n.supportAssetFuelChip,
      'Phone' => l10n.supportAssetPhone,
      'Mobile holder' => l10n.supportAssetMobileHolder,
      'Civil ID copy' => l10n.supportDocTypeCivilIdCopy,
      'License Copy' => l10n.supportDocTypeLicenseCopy,
      'Work permit copy' => l10n.supportDocTypeWorkPermitCopy,
      'Registration copy' => l10n.supportDocTypeRegistrationCopy,
      'Vehicle document copy' => l10n.supportDocTypeVehicleDocumentCopy,
      'Salary certification' => l10n.supportDocTypeSalaryCertification,
      'Renewal' => l10n.supportRequestModeRenewal,
      'First Time' => l10n.supportRequestModeFirstTime,
      'Lost' => l10n.supportAssetStatusLost,
      'Damaged' => l10n.supportAssetStatusDamaged,
      'English' => l10n.english,
      'Arabic' => l10n.arabic,
      'Email' => l10n.supportDeliveryMethodEmail,
      'Pickup' => l10n.supportDeliveryMethodPickup,
      'Low' => l10n.supportSeverityLow,
      'Medium' => l10n.supportSeverityMedium,
      'High' => l10n.supportSeverityHigh,
      _ => value,
    };
  }

  Future<void> _pickDate({
    required ValueChanged<DateTime> onPicked,
    DateTime? initial,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) onPicked(picked);
  }

  Future<void> _pickFile() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _files.add((
        name: picked.name,
        bytes: bytes,
        contentType: 'image/jpeg',
      ));
    });
  }

  Future<List<Map<String, dynamic>>> _uploadFiles() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) throw Exception('not_authenticated');
    final out = <Map<String, dynamic>>[];
    for (final file in _files) {
      final key =
          '$uid/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      await Supabase.instance.client.storage
          .from('request-attachments')
          .uploadBinary(
            key,
            file.bytes,
            fileOptions: FileOptions(contentType: file.contentType, upsert: false),
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

  Future<void> _submit() async {
    final l10n = context.l10n;
    setState(() => _submitting = true);
    try {
      final payload = <String, dynamic>{
        'comment': _commentCtrl.text.trim(),
        'justification': _justificationCtrl.text.trim(),
        'declaration_accepted': _declaration,
      };

      double? amount;
      DateTime? start;
      DateTime? end;
      String? details;
      String? severity;

      switch (widget.type) {
        case 'leave':
          if (_chip == null || _from == null || _to == null) {
            throw Exception(l10n.supportErrorLeaveTypeDatesRequired);
          }
          if (_justificationCtrl.text.trim().isEmpty) {
            throw Exception(l10n.supportErrorJustificationRequired);
          }
          payload['leave_type'] = _chip;
          payload['leave_subtype'] = _chip;
          start = _from;
          end = _to;
        case 'sick_leave':
          if (_chip == null || _from == null || _to == null) {
            throw Exception(l10n.supportErrorLeaveTypeDatesRequired);
          }
          if (_justificationCtrl.text.trim().isEmpty) {
            throw Exception(l10n.supportErrorSymptomsRequired);
          }
          if (_files.isEmpty) {
            throw Exception(l10n.supportErrorMedicalDocsRequired);
          }
          payload['leave_subtype'] = _chip;
          payload['symptoms_details'] = _justificationCtrl.text.trim();
          start = _from;
          end = _to;
        case 'loan':
          amount = double.tryParse(_amountCtrl.text.trim());
          if (amount == null || amount <= 0 || _tenureMonths == null) {
            throw Exception(l10n.supportErrorAmountTenureRequired);
          }
          if (_neededBy == null || _reasonCtrl.text.trim().isEmpty) {
            throw Exception(l10n.supportErrorNeededByReasonRequired);
          }
          payload['tenure_months'] = _tenureMonths;
          payload['needed_by'] = _neededBy!.toIso8601String().split('T').first;
          payload['reason'] = _reasonCtrl.text.trim();
        case 'asset':
          if (_chip == null || _mode == null || _assetStatus == null) {
            throw Exception(l10n.supportErrorAssetFieldsRequired);
          }
          if (_justificationCtrl.text.trim().isEmpty) {
            throw Exception(l10n.supportErrorJustificationRequired);
          }
          payload['asset_type'] = _chip;
          payload['size'] = _size;
          payload['quantity'] = int.tryParse(_qtyCtrl.text.trim()) ?? 1;
          payload['request_mode'] = _mode;
          payload['asset_current_status'] = _assetStatus;
        case 'fuel':
          amount = double.tryParse(_amountCtrl.text.trim());
          if (amount == null || amount <= 0 || _salaryMonth == null) {
            throw Exception(l10n.supportErrorAmountPeriodRequired);
          }
          if (_files.isEmpty) {
            throw Exception(l10n.supportErrorFuelReceiptsRequired);
          }
          payload['period_month'] =
              '${_salaryMonth!.year}-${_salaryMonth!.month.toString().padLeft(2, '0')}';
          payload['distance_km'] =
              double.tryParse(_distanceCtrl.text.trim()) ?? 0;
        case 'document':
          if (_chip == null ||
              _language == null ||
              _deliveryMethod == null ||
              _neededBy == null) {
            throw Exception(l10n.supportErrorDocumentFieldsRequired);
          }
          payload['document_type'] = _chip;
          payload['language'] = _language;
          payload['delivery_method'] = _deliveryMethod;
          payload['needed_by'] = _neededBy!.toIso8601String().split('T').first;
        case 'complaint':
          if (_categoryKey == null ||
              _severity == null ||
              _subjectCtrl.text.trim().isEmpty ||
              _descriptionCtrl.text.trim().isEmpty) {
            throw Exception(l10n.supportErrorComplaintFieldsRequired);
          }
          payload['category'] = _categoryKey;
          payload['subject'] = _subjectCtrl.text.trim();
          payload['description'] = _descriptionCtrl.text.trim();
          severity = _severity!.toLowerCase();
          details = _descriptionCtrl.text.trim();
        case 'salary_justification':
          if (_salaryMonth == null ||
              _expectedCtrl.text.trim().isEmpty ||
              _receivedCtrl.text.trim().isEmpty ||
              _justificationCtrl.text.trim().isEmpty) {
            throw Exception(l10n.supportErrorSalaryFieldsRequired);
          }
          payload['salary_month'] =
              '${_salaryMonth!.year}-${_salaryMonth!.month.toString().padLeft(2, '0')}';
          payload['expected_amount'] =
              double.tryParse(_expectedCtrl.text.trim());
          payload['received_amount'] =
              double.tryParse(_receivedCtrl.text.trim());
      }

      if (!_declaration &&
          {'leave', 'loan', 'asset'}.contains(widget.type)) {
        throw Exception(l10n.supportErrorAcceptDeclaration);
      }

      final attachments = _files.isEmpty ? <Map<String, dynamic>>[] : await _uploadFiles();

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _chips(List<String> options) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((o) {
        final selected = _chip == o;
        return ChoiceChip(
          label: Text(_optionLabel(o)),
          selected: selected,
          onSelected: (_) => setState(() => _chip = o),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tenureAsync = ref.watch(loanTenureOptionsProvider);
    final categoriesAsync = ref.watch(complaintCategoriesProvider);
    final loanGated = widget.type == 'loan' &&
        (tenureAsync.asData?.value.isEmpty ?? true);
    final complaintGated = widget.type == 'complaint' &&
        (categoriesAsync.asData?.value.isEmpty ?? true);
    final catalogBlocked = loanGated || complaintGated;
    final needsDeclaration =
        {'leave', 'loan', 'asset'}.contains(widget.type) && !_declaration;

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          if (widget.type == 'leave') ...[
            Text(l10n.supportFieldLeaveType,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _chips(kLeaveTypes),
            const SizedBox(height: 12),
            _DateRow(
              label: l10n.supportFieldFrom,
              value: _from,
              onTap: () => _pickDate(
                onPicked: (d) => setState(() => _from = d),
                initial: _from,
              ),
            ),
            _DateRow(
              label: l10n.supportFieldTo,
              value: _to,
              onTap: () => _pickDate(
                onPicked: (d) => setState(() => _to = d),
                initial: _to,
              ),
            ),
            TextField(
              controller: _commentCtrl,
              decoration: InputDecoration(
                labelText: l10n.supportFieldCommentOptional,
                hintText: l10n.supportHintMentionHere,
              ),
            ),
            TextField(
              controller: _justificationCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                  labelText: l10n.supportFieldJustificationRequired),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.upload_file),
              label: Text(
                _files.isEmpty
                    ? l10n.supportAttachmentOptional
                    : l10n.supportFilesSelected(_files.length),
              ),
            ),
          ],
          if (widget.type == 'sick_leave') ...[
            Text(l10n.supportFieldLeaveType,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _chips(kSickLeaveSubtypes),
            const SizedBox(height: 12),
            _DateRow(
              label: l10n.supportFieldFrom,
              value: _from,
              onTap: () => _pickDate(onPicked: (d) => setState(() => _from = d)),
            ),
            _DateRow(
              label: l10n.supportFieldTo,
              value: _to,
              onTap: () => _pickDate(onPicked: (d) => setState(() => _to = d)),
            ),
            TextField(
              controller: _commentCtrl,
              decoration: InputDecoration(
                labelText: l10n.supportFieldComment,
                hintText: l10n.supportHintMentionHere,
              ),
            ),
            TextField(
              controller: _justificationCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l10n.supportFieldSymptomsRequired,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.upload_file),
              label: Text(
                _files.isEmpty
                    ? l10n.supportUploadMedicalCertificate
                    : l10n.supportFilesSelected(_files.length),
              ),
            ),
          ],
          if (widget.type == 'loan') ...[
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration:
                  InputDecoration(labelText: l10n.supportFieldAmountKwdRequired),
            ),
            const SizedBox(height: 8),
            tenureAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e'),
              data: (options) {
                if (options.isEmpty) {
                  return Text(
                    l10n.supportLoanTenureUnavailable,
                    style: const TextStyle(color: AppColors.underReviewAmber),
                  );
                }
                return DropdownButtonFormField<int>(
                  initialValue: _tenureMonths,
                  decoration: InputDecoration(
                      labelText: l10n.supportFieldTenureRequired),
                  items: options
                      .map(
                        (o) => DropdownMenuItem(
                          value: o.months,
                          child: Text(o.label),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _tenureMonths = v),
                );
              },
            ),
            _DateRow(
              label: l10n.supportFieldNeededBy,
              value: _neededBy,
              onTap: () =>
                  _pickDate(onPicked: (d) => setState(() => _neededBy = d)),
            ),
            TextField(
              controller: _reasonCtrl,
              maxLines: 3,
              decoration:
                  InputDecoration(labelText: l10n.supportFieldReasonRequired),
            ),
          ],
          if (widget.type == 'asset') ...[
            Text(l10n.supportFieldAssetType,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _chips(kAssetTypes),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['S', 'M', 'L', 'XL', 'XXL'].map((s) {
                return ChoiceChip(
                  label: Text(s),
                  selected: _size == s,
                  onSelected: (_) => setState(() => _size = s),
                );
              }).toList(),
            ),
            TextField(
              controller: _qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.supportFieldQuantity),
            ),
            Wrap(
              spacing: 8,
              children: ['Renewal', 'First Time'].map((m) {
                return ChoiceChip(
                  label: Text(_optionLabel(m)),
                  selected: _mode == m,
                  onSelected: (_) => setState(() => _mode = m),
                );
              }).toList(),
            ),
            Wrap(
              spacing: 8,
              children: ['Lost', 'Damaged'].map((s) {
                return ChoiceChip(
                  label: Text(_optionLabel(s)),
                  selected: _assetStatus == s,
                  onSelected: (_) => setState(() => _assetStatus = s),
                );
              }).toList(),
            ),
            TextField(
              controller: _justificationCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                  labelText: l10n.supportFieldJustificationRequired),
            ),
          ],
          if (widget.type == 'fuel') ...[
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration:
                  InputDecoration(labelText: l10n.supportFieldAmountKwdRequired),
            ),
            _DateRow(
              label: l10n.supportFieldPeriodMonth,
              value: _salaryMonth,
              onTap: () =>
                  _pickDate(onPicked: (d) => setState(() => _salaryMonth = d)),
            ),
            TextField(
              controller: _distanceCtrl,
              keyboardType: TextInputType.number,
              decoration:
                  InputDecoration(labelText: l10n.supportFieldDistanceKm),
            ),
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.upload_file),
              label: Text(
                _files.isEmpty
                    ? l10n.supportUploadFuelReceipts
                    : l10n.supportFilesSelected(_files.length),
              ),
            ),
          ],
          if (widget.type == 'document') ...[
            Text(l10n.supportFieldDocumentType,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _chips(kDocumentTypes),
            Wrap(
              spacing: 8,
              children: ['English', 'Arabic'].map((l) {
                return ChoiceChip(
                  label: Text(_optionLabel(l)),
                  selected: _language == l,
                  onSelected: (_) => setState(() => _language = l),
                );
              }).toList(),
            ),
            Wrap(
              spacing: 8,
              children: ['Email', 'Pickup'].map((m) {
                return ChoiceChip(
                  label: Text(_optionLabel(m)),
                  selected: _deliveryMethod == m,
                  onSelected: (_) => setState(() => _deliveryMethod = m),
                );
              }).toList(),
            ),
            _DateRow(
              label: l10n.supportFieldNeededBy,
              value: _neededBy,
              onTap: () =>
                  _pickDate(onPicked: (d) => setState(() => _neededBy = d)),
            ),
            TextField(
              controller: _commentCtrl,
              decoration: InputDecoration(
                labelText: l10n.supportFieldCommentOptional,
                hintText: l10n.supportHintMentionHere,
              ),
            ),
          ],
          if (widget.type == 'complaint') ...[
            categoriesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e'),
              data: (cats) {
                if (cats.isEmpty) {
                  return Text(
                    l10n.supportComplaintCategoriesUnavailable,
                    style: const TextStyle(color: AppColors.underReviewAmber),
                  );
                }
                return DropdownButtonFormField<String>(
                  initialValue: _categoryKey,
                  decoration: InputDecoration(
                      labelText: l10n.supportFieldCategoryRequired),
                  items: cats
                      .map(
                        (c) => DropdownMenuItem(
                          value: c.key,
                          child: Text(c.labelEn),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _categoryKey = v),
                );
              },
            ),
            Wrap(
              spacing: 8,
              children: ['Low', 'Medium', 'High'].map((s) {
                return ChoiceChip(
                  label: Text(_optionLabel(s)),
                  selected: _severity == s,
                  onSelected: (_) => setState(() => _severity = s),
                );
              }).toList(),
            ),
            TextField(
              controller: _subjectCtrl,
              decoration:
                  InputDecoration(labelText: l10n.supportFieldSubjectRequired),
            ),
            TextField(
              controller: _descriptionCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                  labelText: l10n.supportFieldDescriptionRequired),
            ),
          ],
          if (widget.type == 'salary_justification') ...[
            _DateRow(
              label: l10n.supportFieldSalaryMonth,
              value: _salaryMonth,
              onTap: () =>
                  _pickDate(onPicked: (d) => setState(() => _salaryMonth = d)),
            ),
            TextField(
              controller: _expectedCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText: l10n.supportFieldExpectedAmountRequired),
            ),
            TextField(
              controller: _receivedCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText: l10n.supportFieldReceivedAmountRequired),
            ),
            TextField(
              controller: _commentCtrl,
              decoration: InputDecoration(
                labelText: l10n.supportFieldComment,
                hintText: l10n.supportHintMentionHere,
              ),
            ),
            TextField(
              controller: _justificationCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                  labelText: l10n.supportFieldJustificationRequired),
            ),
          ],
          if (widget.type == 'loan') ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.upload_file),
              label: Text(
                _files.isEmpty
                    ? l10n.supportSupportingDocument
                    : l10n.supportFilesSelected(_files.length),
              ),
            ),
          ],
          if (widget.type == 'asset') ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(
                _files.isEmpty
                    ? l10n.supportPhotoOptional
                    : l10n.supportFilesSelected(_files.length),
              ),
            ),
          ],
          if (widget.type == 'complaint') ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.upload_file),
              label: Text(
                _files.isEmpty
                    ? l10n.supportAttachmentOptional
                    : l10n.supportFilesSelected(_files.length),
              ),
            ),
          ],
          if (widget.type == 'salary_justification') ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.upload_file),
              label: Text(
                _files.isEmpty
                    ? l10n.supportAttachPayslipOptional
                    : l10n.supportFilesSelected(_files.length),
              ),
            ),
          ],
          if ({'leave', 'loan', 'asset'}.contains(widget.type)) ...[
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _declaration,
              onChanged: (v) => setState(() => _declaration = v ?? false),
              title: Text(
                widget.type == 'leave'
                    ? l10n.supportDeclarationLeave
                    : widget.type == 'loan'
                        ? l10n.supportDeclarationLoan
                        : l10n.supportDeclarationAsset,
                style: const TextStyle(fontSize: 12),
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed:
                (_submitting || catalogBlocked || needsDeclaration) ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    catalogBlocked
                        ? l10n.supportTemporarilyUnavailable
                        : l10n.supportSubmitRequest,
                  ),
          ),
        ),
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(
        value == null
            ? context.l10n.selectDate
            : '${value!.year}-${value!.month.toString().padLeft(2, '0')}-${value!.day.toString().padLeft(2, '0')}',
      ),
      trailing: const Icon(Icons.calendar_today_outlined),
      onTap: onTap,
    );
  }
}
