import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../../../../domain/entities/custom_slot.dart';
import '../../../core/app_ui_constants.dart';
import '../library_form/seat_numbering_section.dart';

/// Room types are stored as all-day slots (PGs don't sell hourly shifts).
const int defaultPgInventoryStartTime = 0;
const int defaultPgInventoryEndTime = 1439;

/// Bottom sheet to add or edit a room type: name, rent, beds, bed numbering,
/// and (when editing) active status and delete.
class RoomTypeSheet extends StatefulWidget {
  const RoomTypeSheet({
    super.key,
    this.slot,
    this.initialName,
    required this.onSave,
    this.onToggleActive,
    this.onDelete,
  });

  /// Room type being edited; null to create a new one.
  final CustomSlot? slot;

  /// Pre-filled name when adding from a quick-add template.
  final String? initialName;

  /// Edit only: flips the room type between active and inactive.
  final VoidCallback? onToggleActive;

  /// Edit only: deletes the room type (the caller confirms first).
  final VoidCallback? onDelete;

  /// (name, startTime, endTime, price, capacity, seatPrefix, seatStartNumber)
  final Future<void> Function(String, int, int, double, int, String?, int?)
  onSave;

  @override
  State<RoomTypeSheet> createState() => _RoomTypeSheetState();
}

class _RoomTypeSheetState extends State<RoomTypeSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _capacityController = TextEditingController();
  final _prefixController = TextEditingController();
  final _startNumberController = TextEditingController();
  bool _customSeatNumbering = false;
  bool _isSubmitting = false;
  late bool _isActive = widget.slot?.isActive ?? true;

  bool get _isEdit => widget.slot != null;

  @override
  void initState() {
    super.initState();
    final slot = widget.slot;
    if (slot == null && widget.initialName != null) {
      _nameController.text = widget.initialName!;
    }
    if (slot != null) {
      _nameController.text = slot.name;
      _priceController.text = slot.price.toStringAsFixed(0);
      _capacityController.text = slot.capacity.toString();
      if (slot.seatPrefix != null || slot.seatStartNumber != null) {
        _customSeatNumbering = true;
        _prefixController.text = slot.seatPrefix ?? '';
        _startNumberController.text = slot.seatStartNumber?.toString() ?? '';
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _capacityController.dispose();
    _prefixController.dispose();
    _startNumberController.dispose();
    super.dispose();
  }

  InputDecoration _decoration({
    required String label,
    String? hint,
    IconData? icon,
    String? prefixText,
  }) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
      borderSide: BorderSide(color: c, width: w),
    );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixText: prefixText,
      prefixStyle: const TextStyle(color: AppUIConstants.textPrimary),
      labelStyle: const TextStyle(color: AppUIConstants.textSecondary),
      hintStyle: const TextStyle(color: AppUIConstants.textTertiary),
      prefixIcon: icon == null
          ? null
          : Icon(icon, size: 20, color: AppUIConstants.textTertiary),
      filled: true,
      fillColor: AppUIConstants.surfaceMuted,
      border: border(AppUIConstants.border),
      enabledBorder: border(AppUIConstants.border),
      focusedBorder: border(AppUIConstants.primary, 1.6),
      errorBorder: border(AppUIConstants.error),
      focusedErrorBorder: border(AppUIConstants.error, 1.6),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final slot = widget.slot;
    final prefix =
        _customSeatNumbering && _prefixController.text.trim().isNotEmpty
        ? _prefixController.text.trim()
        : null;
    final startNumber = _customSeatNumbering
        ? int.tryParse(_startNumberController.text.trim())
        : null;

    setState(() => _isSubmitting = true);
    await widget.onSave(
      _nameController.text.trim(),
      slot?.startTime ?? defaultPgInventoryStartTime,
      slot?.endTime ?? defaultPgInventoryEndTime,
      double.parse(_priceController.text),
      int.parse(_capacityController.text),
      prefix,
      startNumber,
    );
    if (mounted) Navigator.pop(context);
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: AppUIConstants.textTertiary,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppUIConstants.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: _SheetHandle()),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppUIConstants.primarySoft,
                          borderRadius: BorderRadius.circular(
                            AppUIConstants.radiusSm,
                          ),
                        ),
                        child: Icon(
                          _isEdit
                              ? Icons.edit_rounded
                              : Icons.add_home_work_rounded,
                          color: AppUIConstants.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isEdit ? 'Edit room type' : 'Add a room type',
                              style: AppUIConstants.headingMd,
                            ),
                            Text(
                              _isEdit
                                  ? 'Update rent, beds and numbering'
                                  : 'Group beds by room type or floor',
                              style: AppUIConstants.bodySm,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppUIConstants.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _sectionLabel('Room type'),
                  TextFormField(
                    controller: _nameController,
                    style: const TextStyle(color: AppUIConstants.textPrimary),
                    textCapitalization: TextCapitalization.words,
                    decoration: _decoration(
                      label: 'Room type name',
                      hint: 'e.g., Double sharing, Ground Floor',
                      icon: Icons.label_outline_rounded,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Room type name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  _sectionLabel('Rent & beds'),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _priceController,
                          style: const TextStyle(
                            color: AppUIConstants.textPrimary,
                          ),
                          decoration: _decoration(
                            label: 'Rent (₹/month)',
                            prefixText: '₹ ',
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Rent is required';
                            }
                            final price = double.tryParse(value);
                            if (price == null || price <= 0) {
                              return 'Enter a valid rent';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _capacityController,
                          style: const TextStyle(
                            color: AppUIConstants.textPrimary,
                          ),
                          onChanged: (_) => setState(() {}),
                          decoration: _decoration(
                            label: 'Beds',
                            hint: 'e.g., 20',
                            icon: Icons.bed_rounded,
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter beds';
                            }
                            final capacity = int.tryParse(value);
                            if (capacity == null || capacity <= 0) {
                              return 'Must be > 0';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _sectionLabel('Bed numbering'),
                  SeatNumberingSection(
                    enabled: _customSeatNumbering,
                    prefixController: _prefixController,
                    startNumberController: _startNumberController,
                    capacityText: _capacityController.text,
                    onToggle: (val) =>
                        setState(() => _customSeatNumbering = val),
                  ),
                  if (_isEdit && widget.onToggleActive != null) ...[
                    const SizedBox(height: 20),
                    _sectionLabel('Status'),
                    Container(
                      decoration: BoxDecoration(
                        color: AppUIConstants.surfaceMuted,
                        borderRadius: BorderRadius.circular(
                          AppUIConstants.radiusMd,
                        ),
                      ),
                      child: SwitchListTile.adaptive(
                        value: _isActive,
                        onChanged: (v) {
                          HapticFeedback.selectionClick();
                          setState(() => _isActive = v);
                          widget.onToggleActive!();
                        },
                        activeTrackColor: AppUIConstants.success,
                        title: const Text(
                          'Accepting residents',
                          style: AppUIConstants.bodyLg,
                        ),
                        subtitle: Text(
                          _isActive
                              ? 'Beds can be booked and assigned'
                              : 'Hidden from new bookings',
                          style: AppUIConstants.bodySm,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSubmitting
                              ? null
                              : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppUIConstants.textSecondary,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            side: const BorderSide(
                              color: AppUIConstants.border,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppUIConstants.radiusMd,
                              ),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submit,
                          style: AppUIConstants.primaryButtonStyle,
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  _isEdit ? 'Save changes' : 'Create room type',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                  if (_isEdit && widget.onDelete != null) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _isSubmitting
                          ? null
                          : () {
                              Navigator.pop(context);
                              widget.onDelete!();
                            },
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Delete room type'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppUIConstants.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 12),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: AppUIConstants.border,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
