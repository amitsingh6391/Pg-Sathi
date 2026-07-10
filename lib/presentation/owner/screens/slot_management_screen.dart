import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/custom_slot.dart';
import '../../../domain/entities/library.dart';
import '../../core/app_ui_constants.dart';
import '../cubit/slot_management_cubit.dart';
import '../cubit/slot_management_state.dart';
import '../widgets/library_form/seat_numbering_section.dart';

const int _defaultPgInventoryStartTime = 0;
const int _defaultPgInventoryEndTime = 1439;

/// Screen for managing custom slots for a library.
class SlotManagementScreen extends StatefulWidget {
  const SlotManagementScreen({super.key, required this.library});

  final Library library;

  @override
  State<SlotManagementScreen> createState() => _SlotManagementScreenState();
}

class _SlotManagementScreenState extends State<SlotManagementScreen> {
  bool _isAddFormExpanded = false;
  final _totalSeatController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<SlotManagementCubit>().loadSlots(widget.library.id);
    final capacity = widget.library.totalSeatCapacity;
    if (capacity != null && capacity > 0) {
      _totalSeatController.text = capacity.toString();
    }
  }

  @override
  void dispose() {
    _totalSeatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUIConstants.background,
      appBar: AppBar(
        title: const Text('Manage Beds'),
        elevation: 0,
        backgroundColor: AppUIConstants.surface,
        foregroundColor: AppUIConstants.textPrimary,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: BlocConsumer<SlotManagementCubit, SlotManagementState>(
          listener: (context, state) {
            if (state.hasSuccess && state.successMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.successMessage!),
                  backgroundColor: AppUIConstants.success,
                  behavior: SnackBarBehavior.floating,
                ),
              );
              // Collapse form if expanded
              if (_isAddFormExpanded) {
                setState(() {
                  _isAddFormExpanded = false;
                });
              }
              context.read<SlotManagementCubit>().resetError();
            } else if (state.hasError && state.failure != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.failure!.message ?? 'An error occurred'),
                  backgroundColor: AppUIConstants.error,
                  behavior: SnackBarBehavior.floating,
                ),
              );
              context.read<SlotManagementCubit>().resetError();
            }
          },
          builder: (context, state) {
            if (state.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.event_seat_rounded,
                        color: AppUIConstants.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Total Beds in PG',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppUIConstants.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 72,
                        height: 40,
                        child: TextFormField(
                          controller: _totalSeatController,
                          textAlign: TextAlign.center,
                          keyboardType: const TextInputType.numberWithOptions(),
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) =>
                              FocusScope.of(context).unfocus(),
                          decoration: InputDecoration(
                            hintText: '—',
                            hintStyle: TextStyle(
                              color: AppUIConstants.textTertiary,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: AppUIConstants.border,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: AppUIConstants.border,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: AppUIConstants.primary,
                                width: 1.5,
                              ),
                            ),
                            filled: true,
                            fillColor: AppUIConstants.background,
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (value) {
                            final parsed = int.tryParse(value);
                            context
                                .read<SlotManagementCubit>()
                                .updateTotalSeatCapacity(
                                  widget.library,
                                  parsed != null && parsed > 0 ? parsed : null,
                                );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Add bed group form (collapsible)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: _AddSlotForm(
                    isExpanded: _isAddFormExpanded,
                    libraryId: widget.library.id,
                    onToggle: () {
                      setState(() {
                        _isAddFormExpanded = !_isAddFormExpanded;
                      });
                    },
                    onSuccess: () {
                      setState(() {
                        _isAddFormExpanded = false;
                      });
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // Bed groups list
                Expanded(
                  child: state.slots.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: state.slots.length,
                          itemBuilder: (context, index) {
                            // Show native ad at the end of the list

                            return _SlotCard(
                              slot: state.slots[index],
                              onEdit: () => _showEditSlotDialog(
                                context,
                                state.slots[index],
                              ),
                              onToggleActive: () {
                                context
                                    .read<SlotManagementCubit>()
                                    .toggleSlotActive(state.slots[index]);
                              },
                              onDelete: () => _showDeleteConfirmation(
                                context,
                                state.slots[index],
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bed_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No bed groups created yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first bed group',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  void _showEditSlotDialog(BuildContext context, CustomSlot slot) {
    final cubit = context.read<SlotManagementCubit>();
    showDialog(
      context: context,
      builder: (dialogContext) => _SlotDialog(
        libraryId: widget.library.id,
        slot: slot,
        onSave:
            (
              name,
              startTime,
              endTime,
              price,
              capacity,
              seatPrefix,
              seatStartNumber,
            ) {
              final updated = slot.copyWith(
                name: name,
                startTime: startTime,
                endTime: endTime,
                price: price,
                capacity: capacity,
                seatPrefix: seatPrefix,
                seatStartNumber: seatStartNumber,
              );
              cubit.updateSlotForLibrary(updated);
            },
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, CustomSlot slot) {
    final cubit = context.read<SlotManagementCubit>();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Bed Group'),
        content: Text(
          'Are you sure you want to delete "${slot.name}"?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              cubit.deleteSlotForLibrary(slot.id);
            },
            style: TextButton.styleFrom(foregroundColor: AppUIConstants.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _AddSlotForm extends StatefulWidget {
  const _AddSlotForm({
    required this.isExpanded,
    required this.libraryId,
    required this.onToggle,
    required this.onSuccess,
  });

  final bool isExpanded;
  final String libraryId;
  final VoidCallback onToggle;
  final VoidCallback onSuccess;

  @override
  State<_AddSlotForm> createState() => _AddSlotFormState();
}

class _AddSlotFormState extends State<_AddSlotForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _capacityController = TextEditingController();
  final _prefixController = TextEditingController();
  final _startNumberController = TextEditingController();
  bool _isSubmitting = false;
  bool _customSeatNumbering = false;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _capacityController.dispose();
    _prefixController.dispose();
    _startNumberController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);

    final cubit = context.read<SlotManagementCubit>();
    await cubit.createSlotForLibrary(
      name: _nameController.text.trim(),
      startTime: _defaultPgInventoryStartTime,
      endTime: _defaultPgInventoryEndTime,
      price: double.parse(_priceController.text),
      capacity: int.parse(_capacityController.text),
      seatPrefix: _customSeatNumbering
          ? _prefixController.text.trim().isEmpty
                ? null
                : _prefixController.text.trim()
          : null,
      seatStartNumber: _customSeatNumbering
          ? int.tryParse(_startNumberController.text.trim())
          : null,
    );

    setState(() => _isSubmitting = false);

    // Reset form and collapse
    _nameController.clear();
    _priceController.clear();
    _capacityController.clear();
    _prefixController.clear();
    _startNumberController.clear();
    _customSeatNumbering = false;
    widget.onSuccess();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isExpanded
              ? AppUIConstants.primary.withValues(alpha: 0.3)
              : AppUIConstants.border,
          width: widget.isExpanded ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: widget.isExpanded ? 0.08 : 0.03,
            ),
            blurRadius: widget.isExpanded ? 16 : 8,
            offset: Offset(0, widget.isExpanded ? 4 : 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header - Always visible
          InkWell(
            onTap: widget.onToggle,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppUIConstants.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.add_circle_outline_rounded,
                      color: AppUIConstants.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Add Bed Group',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppUIConstants.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.isExpanded
                              ? 'Fill in the details below'
                              : 'Tap to create a new bed group',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 300),
                    turns: widget.isExpanded ? 0.5 : 0,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.grey.shade600,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Form Content - Collapsible
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: widget.isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Bed Group Name',
                        hintText: 'e.g., Ground Floor, Room A',
                        prefixIcon: const Icon(Icons.label_outline_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Bed group name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Price and Capacity Row
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _priceController,
                            decoration: InputDecoration(
                              labelText: 'Price (₹/month)',
                              prefixIcon: const Icon(
                                Icons.currency_rupee_rounded,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Required';
                              }
                              final price = double.tryParse(value);
                              if (price == null || price <= 0) {
                                return 'Invalid';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _capacityController,
                            decoration: InputDecoration(
                              labelText: 'Beds',
                              prefixIcon: const Icon(Icons.event_seat_rounded),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Required';
                              }
                              final capacity = int.tryParse(value);
                              if (capacity == null || capacity <= 0) {
                                return 'Invalid';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Seat Numbering Toggle ─────────────────────────────
                    SeatNumberingSection(
                      enabled: _customSeatNumbering,
                      prefixController: _prefixController,
                      startNumberController: _startNumberController,
                      capacityText: _capacityController.text,
                      onToggle: (val) =>
                          setState(() => _customSeatNumbering = val),
                    ),
                    const SizedBox(height: 24),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: widget.isExpanded
                                ? () {
                                    _nameController.clear();
                                    _priceController.clear();
                                    _capacityController.clear();
                                    _prefixController.clear();
                                    _startNumberController.clear();
                                    _customSeatNumbering = false;
                                    widget.onToggle();
                                  }
                                : null,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _handleSubmit,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: AppUIConstants.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text('Create Bed Group'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({
    required this.slot,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
  });

  final CustomSlot slot;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: slot.isActive
              ? const Color(0xFF10B981).withValues(alpha: 0.3)
              : Colors.grey.shade300,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    slot.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: slot.isActive
                        ? const Color(0xFF10B981).withValues(alpha: 0.1)
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    slot.isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: slot.isActive
                          ? const Color(0xFF10B981)
                          : Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${slot.capacity} beds • ₹${slot.price.toStringAsFixed(0)}/month',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            trailing: PopupMenuButton(
              icon: const Icon(Icons.more_vert_rounded),
              itemBuilder: (context) => [
                PopupMenuItem(
                  child: const Row(
                    children: [
                      Icon(Icons.edit_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                  onTap: () =>
                      Future.delayed(const Duration(milliseconds: 100), onEdit),
                ),
                PopupMenuItem(
                  child: Row(
                    children: [
                      Icon(
                        slot.isActive
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(slot.isActive ? 'Deactivate' : 'Activate'),
                    ],
                  ),
                  onTap: () => Future.delayed(
                    const Duration(milliseconds: 100),
                    onToggleActive,
                  ),
                ),
                PopupMenuItem(
                  child: const Row(
                    children: [
                      Icon(
                        Icons.delete_rounded,
                        size: 18,
                        color: Color(0xFFDC2626),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Delete',
                        style: TextStyle(color: Color(0xFFDC2626)),
                      ),
                    ],
                  ),
                  onTap: () => Future.delayed(
                    const Duration(milliseconds: 100),
                    onDelete,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotDialog extends StatefulWidget {
  const _SlotDialog({required this.libraryId, this.slot, required this.onSave});

  final String libraryId;
  final CustomSlot? slot;
  final void Function(String, int, int, double, int, String?, int?) onSave;

  @override
  State<_SlotDialog> createState() => _SlotDialogState();
}

class _SlotDialogState extends State<_SlotDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _capacityController = TextEditingController();
  final _prefixController = TextEditingController();
  final _startNumberController = TextEditingController();
  bool _customSeatNumbering = false;

  @override
  void initState() {
    super.initState();
    if (widget.slot != null) {
      _nameController.text = widget.slot!.name;
      _priceController.text = widget.slot!.price.toStringAsFixed(0);
      _capacityController.text = widget.slot!.capacity.toString();
      if (widget.slot!.seatPrefix != null ||
          widget.slot!.seatStartNumber != null) {
        _customSeatNumbering = true;
        _prefixController.text = widget.slot!.seatPrefix ?? '';
        _startNumberController.text =
            widget.slot!.seatStartNumber?.toString() ?? '';
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.slot == null ? 'Add Bed Group' : 'Edit Bed Group'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Bed Group Name',
                  hintText: 'e.g., Ground Floor, Room A',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Bed group name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Price (₹/month)',
                  border: OutlineInputBorder(),
                  prefixText: '₹ ',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Price is required';
                  }
                  final price = double.tryParse(value);
                  if (price == null || price <= 0) {
                    return 'Enter a valid price';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _capacityController,
                decoration: const InputDecoration(
                  labelText: 'Number of Beds *',
                  hintText: 'e.g., 20',
                  prefixIcon: Icon(Icons.event_seat_rounded),
                  border: OutlineInputBorder(),
                  helperText: 'Total beds available for this inventory group',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter number of beds';
                  }
                  final capacity = int.tryParse(value);
                  if (capacity == null || capacity <= 0) {
                    return 'Beds must be greater than 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // ── Seat Numbering Toggle ─────────────────────────────
              StatefulBuilder(
                builder: (context, setLocal) => SeatNumberingSection(
                  enabled: _customSeatNumbering,
                  prefixController: _prefixController,
                  startNumberController: _startNumberController,
                  capacityText: _capacityController.text,
                  onToggle: (val) {
                    setState(() => _customSeatNumbering = val);
                    setLocal(() {});
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              final prefix =
                  _customSeatNumbering &&
                      _prefixController.text.trim().isNotEmpty
                  ? _prefixController.text.trim()
                  : null;
              final startNumber = _customSeatNumbering
                  ? int.tryParse(_startNumberController.text.trim())
                  : null;
              widget.onSave(
                _nameController.text.trim(),
                widget.slot?.startTime ?? _defaultPgInventoryStartTime,
                widget.slot?.endTime ?? _defaultPgInventoryEndTime,
                double.parse(_priceController.text),
                int.parse(_capacityController.text),
                prefix,
                startNumber,
              );
              Navigator.pop(context);
            }
          },
          child: Text(widget.slot == null ? 'Create' : 'Update'),
        ),
      ],
    );
  }
}
