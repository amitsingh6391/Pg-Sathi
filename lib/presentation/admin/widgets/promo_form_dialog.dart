import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/di/injection_container.dart';
import '../../../data/services/storage_service.dart';
import '../../../domain/entities/promo_offer.dart';
import '../../../domain/usecases/promo/promo_usecases.dart';
import '../../core/app_ui_constants.dart';
import '../../core/widgets/premium_kit.dart';
import 'promo_preview_dialog.dart';

/// Dialog for creating/editing a promo offer.
class PromoFormDialog extends StatefulWidget {
  const PromoFormDialog({super.key, this.promo});

  final PromoOffer? promo;

  @override
  State<PromoFormDialog> createState() => _PromoFormDialogState();
}

class _PromoFormDialogState extends State<PromoFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();
  late TextEditingController _titleController;
  late TextEditingController _ctaTextController;
  late TextEditingController _ctaValueController;
  late TextEditingController _priorityController;

  File? _selectedImage;
  String? _existingImageUrl;

  PromoCtaAction _ctaAction = PromoCtaAction.whatsapp;
  PromoTargetAudience _targetAudience = PromoTargetAudience.all;
  PromoDisplayFrequency _displayFrequency = PromoDisplayFrequency.daily;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isActive = true;
  bool _isSaving = false;

  bool get isEditing => widget.promo != null;

  @override
  void initState() {
    super.initState();
    final promo = widget.promo;
    _titleController = TextEditingController(text: promo?.title ?? '');
    _existingImageUrl = promo?.imageUrl;
    _ctaTextController = TextEditingController(
      text: promo?.ctaText ?? "I'm Interested",
    );
    _ctaValueController = TextEditingController(text: promo?.ctaValue ?? '');
    _priorityController = TextEditingController(
      text: (promo?.priority ?? 1).toString(),
    );

    if (promo != null) {
      _ctaAction = promo.ctaAction;
      _targetAudience = promo.targetAudience;
      _displayFrequency = promo.displayFrequency;
      _startDate = promo.startDate;
      _endDate = promo.endDate;
      _isActive = promo.isActive;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _ctaTextController.dispose();
    _ctaValueController.dispose();
    _priorityController.dispose();
    super.dispose();
  }

  InputDecoration _decoration(String label, {String? hint}) {
    OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppUIConstants.radiusSm + 2),
      borderSide: BorderSide(color: c, width: w),
    );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: AppUIConstants.surfaceMuted,
      labelStyle: const TextStyle(color: AppUIConstants.textSecondary),
      hintStyle: const TextStyle(color: AppUIConstants.textTertiary),
      border: b(AppUIConstants.border),
      enabledBorder: b(AppUIConstants.border),
      focusedBorder: b(AppUIConstants.primaryLight, 1.5),
      errorBorder: b(AppUIConstants.error),
      focusedErrorBorder: b(AppUIConstants.error, 1.5),
    );
  }

  Widget _section(String title, IconData icon, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppUIConstants.spacingMd),
      child: PremiumCard(
        padding: const EdgeInsets.all(AppUIConstants.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppUIConstants.primaryLight.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(
                      AppUIConstants.radiusSm,
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: AppUIConstants.primaryLight,
                  ),
                ),
                const SizedBox(width: 10),
                Text(title, style: AppUIConstants.headingSm),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 640;
    final form = Column(
      children: [
        _buildHeader(wide),
        Expanded(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(AppUIConstants.spacingLg),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _section('Basics', Icons.title_rounded, [
                    _buildTextField(
                      controller: _titleController,
                      label: 'Title',
                      hint: 'e.g., Get 30% Off!',
                      validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    ),
                  ]),
                  _section('Creative', Icons.image_outlined, [
                    _buildImagePicker(),
                  ]),
                  _section('Call to action', Icons.touch_app_outlined, [
                    _buildTextField(
                      controller: _ctaTextController,
                      label: 'Button text',
                      hint: "e.g., I'm Interested",
                    ),
                    const SizedBox(height: 14),
                    _buildDropdown<PromoCtaAction>(
                      label: 'Button action',
                      value: _ctaAction,
                      items: PromoCtaAction.values,
                      itemLabel: _ctaActionLabel,
                      onChanged: (v) => setState(() => _ctaAction = v!),
                    ),
                    const SizedBox(height: 14),
                    _buildTextField(
                      controller: _ctaValueController,
                      label: 'Action value',
                      hint: _ctaActionHint(_ctaAction),
                    ),
                  ]),
                  _section('Targeting', Icons.people_outline_rounded, [
                    _buildDropdown<PromoTargetAudience>(
                      label: 'Target audience',
                      value: _targetAudience,
                      items: PromoTargetAudience.values,
                      itemLabel: _audienceLabel,
                      onChanged: (v) => setState(() => _targetAudience = v!),
                    ),
                    const SizedBox(height: 14),
                    _buildDropdown<PromoDisplayFrequency>(
                      label: 'Display frequency',
                      value: _displayFrequency,
                      items: PromoDisplayFrequency.values,
                      itemLabel: _frequencyLabel,
                      onChanged: (v) => setState(() => _displayFrequency = v!),
                    ),
                    const SizedBox(height: 14),
                    _buildTextField(
                      controller: _priorityController,
                      label: 'Priority (higher = shown first)',
                      hint: '1',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ]),
                  _section('Schedule', Icons.event_outlined, [
                    _buildDatePickers(),
                  ]),
                  _section('Visibility', Icons.visibility_outlined, [
                    _buildActiveSwitch(),
                  ]),
                ],
              ),
            ),
          ),
        ),
        _buildActions(),
      ],
    );

    return Dialog(
      backgroundColor: AppUIConstants.background,
      insetPadding: wide ? const EdgeInsets.all(24) : EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(wide ? AppUIConstants.radiusLg : 0),
      ),
      clipBehavior: Clip.antiAlias,
      child: wide
          ? SizedBox(
              width: 520,
              height: MediaQuery.of(context).size.height * 0.88,
              child: form,
            )
          : SizedBox.expand(child: SafeArea(child: form)),
    );
  }

  Widget _buildHeader(bool wide) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 8, 14),
      decoration: const BoxDecoration(
        color: AppUIConstants.surface,
        border: Border(bottom: BorderSide(color: AppUIConstants.border)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppUIConstants.surfaceMuted,
              borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
            ),
            child: Icon(
              isEditing ? Icons.edit_rounded : Icons.local_offer_rounded,
              color: AppUIConstants.primaryLight,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditing ? 'Edit promo' : 'New promo',
                  style: AppUIConstants.headingMd,
                ),
                const Text(
                  'Shown as a popup on the owner dashboard',
                  style: AppUIConstants.caption,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.close_rounded,
              color: AppUIConstants.textSecondary,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: AppUIConstants.bodyLg,
      decoration: _decoration(label, hint: hint),
    );
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Promo image', style: AppUIConstants.bodyMd),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppUIConstants.surfaceMuted,
              borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
              border: Border.all(color: AppUIConstants.border, width: 1.5),
            ),
            child: _buildImagePreview(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                _selectedImage != null
                    ? 'Image selected'
                    : _existingImageUrl != null && _existingImageUrl!.isNotEmpty
                    ? 'Using existing image'
                    : 'Default image will be used',
                style: AppUIConstants.bodySm.copyWith(
                  color: AppUIConstants.textTertiary,
                ),
              ),
            ),
            if (_selectedImage != null || _existingImageUrl != null)
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedImage = null;
                    _existingImageUrl = null;
                  });
                },
                icon: const Icon(Icons.clear, size: 16),
                label: const Text('Clear'),
                style: TextButton.styleFrom(
                  foregroundColor: AppUIConstants.error,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildImagePreview() {
    if (_selectedImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd - 2),
        child: Image.file(
          _selectedImage!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
      );
    }

    if (_existingImageUrl != null && _existingImageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd - 2),
        child: Image.network(
          _existingImageUrl!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stack) => _buildPlaceholder(),
        ),
      );
    }

    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_photo_alternate_outlined,
          size: 48,
          color: AppUIConstants.textTertiary,
        ),
        const SizedBox(height: 8),
        Text(
          'Tap to select image',
          style: AppUIConstants.bodyMd.copyWith(
            color: AppUIConstants.textTertiary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Recommended: 1080×1920 (9:16)',
          style: AppUIConstants.bodySm.copyWith(
            color: AppUIConstants.textTertiary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Future<void> _pickImage() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (picked != null) {
        setState(() {
          _selectedImage = File(picked.path);
        });
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required String Function(T) itemLabel,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(itemLabel(e))))
          .toList(),
      onChanged: onChanged,
      dropdownColor: AppUIConstants.surfaceMuted,
      isExpanded: true,
      style: AppUIConstants.bodyLg,
      decoration: _decoration(label),
    );
  }

  Widget _buildDatePickers() {
    final formatter = DateFormat('MMM d, yyyy');
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => _pickDate(isStart: true),
            child: InputDecorator(
              decoration: _decoration('Start date'),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _startDate != null ? formatter.format(_startDate!) : 'Now',
                    style: AppUIConstants.bodyLg,
                  ),
                  if (_startDate != null)
                    GestureDetector(
                      onTap: () => setState(() => _startDate = null),
                      child: const Icon(
                        Icons.clear,
                        size: 18,
                        color: AppUIConstants.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            onTap: () => _pickDate(isStart: false),
            child: InputDecorator(
              decoration: _decoration('End date'),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _endDate != null ? formatter.format(_endDate!) : 'Never',
                    style: AppUIConstants.bodyLg,
                  ),
                  if (_endDate != null)
                    GestureDetector(
                      onTap: () => setState(() => _endDate = null),
                      child: const Icon(
                        Icons.clear,
                        size: 18,
                        color: AppUIConstants.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Widget _buildActiveSwitch() {
    return Container(
      padding: const EdgeInsets.all(AppUIConstants.spacingMd),
      decoration: BoxDecoration(
        color: AppUIConstants.surfaceMuted,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        border: Border.all(color: AppUIConstants.border),
      ),
      child: Row(
        children: [
          Icon(
            _isActive ? Icons.visibility : Icons.visibility_off,
            color: _isActive
                ? AppUIConstants.primaryLight
                : AppUIConstants.textTertiary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Active', style: AppUIConstants.bodyLg),
                Text(
                  _isActive
                      ? 'Promo is visible to its audience'
                      : 'Promo is hidden',
                  style: AppUIConstants.bodySm.copyWith(
                    color: AppUIConstants.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isActive,
            onChanged: (v) => setState(() => _isActive = v),
            activeTrackColor: AppUIConstants.primaryLight.withValues(
              alpha: 0.5,
            ),
            activeThumbColor: AppUIConstants.primaryLight,
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: AppUIConstants.surface,
        border: Border(top: BorderSide(color: AppUIConstants.border)),
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: _showPreview,
            icon: const Icon(Icons.visibility_outlined, size: 18),
            label: const Text('Preview'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppUIConstants.primaryLight,
              side: const BorderSide(color: AppUIConstants.primaryLight),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _isSaving ? null : _savePromo,
              style: AppUIConstants.accentButtonStyle,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: _isSaving
                    ? const SizedBox(
                        key: ValueKey('s'),
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        isEditing ? 'Update promo' : 'Create promo',
                        key: const ValueKey('t'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPreview() {
    final previewPromo = PromoOffer(
      id: 'preview',
      title: _titleController.text.trim().isEmpty
          ? 'Promo Title'
          : _titleController.text.trim(),
      imageUrl: '',
      ctaText: _ctaTextController.text.trim().isEmpty
          ? "I'm Interested"
          : _ctaTextController.text.trim(),
      ctaAction: _ctaAction,
      ctaValue: _ctaValueController.text.trim(),
      targetAudience: _targetAudience,
      displayFrequency: _displayFrequency,
      startDate: _startDate,
      endDate: _endDate,
      priority: int.tryParse(_priorityController.text) ?? 1,
      isActive: _isActive,
      createdAt: DateTime.now(),
    );

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) => PromoPreviewDialog(
        promo: previewPromo,
        localImage: _selectedImage,
        existingImageUrl: _existingImageUrl,
      ),
    );
  }

  Future<void> _savePromo() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      String imageUrl;
      if (_selectedImage != null) {
        final storageService = sl<StorageService>();
        imageUrl = await storageService.uploadImage(
          file: _selectedImage!,
          path: 'promo_images/',
        );
      } else if (_existingImageUrl != null && _existingImageUrl!.isNotEmpty) {
        imageUrl = _existingImageUrl!;
      } else {
        imageUrl = '';
      }

      final promo = PromoOffer(
        id: widget.promo?.id ?? '',
        title: _titleController.text.trim(),
        imageUrl: imageUrl,
        ctaText: _ctaTextController.text.trim(),
        ctaAction: _ctaAction,
        ctaValue: _ctaValueController.text.trim(),
        targetAudience: _targetAudience,
        displayFrequency: _displayFrequency,
        startDate: _startDate,
        endDate: _endDate,
        priority: int.tryParse(_priorityController.text) ?? 1,
        isActive: _isActive,
        createdAt: widget.promo?.createdAt ?? DateTime.now(),
      );

      if (isEditing) {
        final updatePromo = sl<UpdatePromo>();
        final result = await updatePromo(promo);
        result.fold(
          (f) => _showError('Failed: ${f.message}'),
          (_) => Navigator.pop(context, promo),
        );
      } else {
        final createPromo = sl<CreatePromo>();
        final result = await createPromo(promo);
        result.fold(
          (f) => _showError('Failed: ${f.message}'),
          (created) => Navigator.pop(context, created),
        );
      }
    } catch (e) {
      _showError('Failed to upload image: $e');
    }

    if (mounted) {
      setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppUIConstants.error),
    );
  }

  String _ctaActionLabel(PromoCtaAction action) {
    switch (action) {
      case PromoCtaAction.whatsapp:
        return 'WhatsApp';
      case PromoCtaAction.link:
        return 'Open URL';
      case PromoCtaAction.screen:
        return 'In-App Screen';
      case PromoCtaAction.dismiss:
        return 'Just Dismiss';
    }
  }

  String _ctaActionHint(PromoCtaAction action) {
    switch (action) {
      case PromoCtaAction.whatsapp:
        return 'e.g., +919548582776';
      case PromoCtaAction.link:
        return 'e.g., https://example.com';
      case PromoCtaAction.screen:
        return 'e.g., /subscription';
      case PromoCtaAction.dismiss:
        return 'Not needed';
    }
  }

  String _audienceLabel(PromoTargetAudience audience) {
    switch (audience) {
      case PromoTargetAudience.all:
        return 'Everyone';
      case PromoTargetAudience.allOwners:
        return 'All Owners';
      case PromoTargetAudience.allStudents:
        return 'All Residents';
      case PromoTargetAudience.freeTier:
        return 'Free Tier Only';
      case PromoTargetAudience.paid:
        return 'Paid Subscribers';
      case PromoTargetAudience.expired:
        return 'Expired Subscriptions';
      case PromoTargetAudience.pendingVerification:
        return 'Pending Verification';
      case PromoTargetAudience.newOwners:
        return 'New Owners (< 7 days)';
      case PromoTargetAudience.activeMembership:
        return 'Active Residents';
      case PromoTargetAudience.expiredMembership:
        return 'Expired Residents';
      case PromoTargetAudience.noMembership:
        return 'No Stay';
    }
  }

  String _frequencyLabel(PromoDisplayFrequency frequency) {
    switch (frequency) {
      case PromoDisplayFrequency.once:
        return 'Once Ever';
      case PromoDisplayFrequency.daily:
        return 'Once Per Day';
      case PromoDisplayFrequency.session:
        return 'Every App Open';
    }
  }
}
