import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../domain/entities/custom_slot.dart';
import '../../../../domain/entities/membership.dart';
import '../../../../domain/entities/payment.dart';

/// Assignment form card for entering tenant details and submitting.
/// Supports room/bed plans with partial rent payment support.
class MembershipAssignmentFormCard extends StatelessWidget {
  const MembershipAssignmentFormCard({
    super.key,
    required this.formKey,
    required this.phoneController,
    this.nameController,
    required this.selectedSeatId,
    required this.expiryDate,
    required this.selectedPlan,
    required this.isSubmitting,
    required this.onExpiryDateChanged,
    required this.onPlanChanged,
    required this.onSubmit,
    required this.onCancel,
    this.selectedCustomSlotId,
    this.selectedCustomSlot,
    this.paymentMethod,
    this.markCashReceived = false,
    this.onPaymentMethodChanged,
    this.onMarkCashReceivedChanged,
    this.paymentReceivedDate,
    this.onPaymentReceivedDateChanged,
    this.amountPaidController,
    this.amountRemainingController,
    this.paymentNotesController,
    this.discountController,
    this.isPartialPayment = false,
    this.onPartialPaymentChanged,
    this.onCalculateTotalPrice,
    this.startDate,
    this.onStartDateChanged,
    this.customDurationDays,
    this.onCustomDurationDaysChanged,
    this.customDurationMonths,
    this.onCustomDurationMonthsChanged,
    this.useCustomDuration = false,
    this.onUseCustomDurationChanged,
    this.customDurationDaysController,
    this.customDurationMonthsController,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController phoneController;
  final TextEditingController? nameController;
  final String selectedSeatId;
  final String? selectedCustomSlotId;
  final CustomSlot? selectedCustomSlot;
  final DateTime expiryDate;
  final MembershipPlan selectedPlan;
  final bool isSubmitting;
  final PaymentMode? paymentMethod;
  final bool markCashReceived;
  final DateTime? paymentReceivedDate;
  final TextEditingController? amountPaidController;
  final TextEditingController? amountRemainingController;
  final TextEditingController? paymentNotesController;
  final TextEditingController? discountController;
  final bool isPartialPayment;
  final ValueChanged<DateTime> onExpiryDateChanged;
  final ValueChanged<MembershipPlan> onPlanChanged;
  final ValueChanged<PaymentMode?>? onPaymentMethodChanged;
  final ValueChanged<bool>? onMarkCashReceivedChanged;
  final ValueChanged<DateTime>? onPaymentReceivedDateChanged;
  final ValueChanged<bool>? onPartialPaymentChanged;
  final double Function()? onCalculateTotalPrice;
  final DateTime? startDate;
  final ValueChanged<DateTime>? onStartDateChanged;
  final int? customDurationDays;
  final ValueChanged<int?>? onCustomDurationDaysChanged;
  final int? customDurationMonths;
  final ValueChanged<int?>? onCustomDurationMonthsChanged;
  final bool useCustomDuration;
  final ValueChanged<bool>? onUseCustomDurationChanged;
  final TextEditingController? customDurationDaysController;
  final TextEditingController? customDurationMonthsController;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.person_add_rounded,
                    color: Color(0xFF10B981),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assign to Bed $selectedSeatId',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        selectedCustomSlot != null
                            ? '${selectedCustomSlot!.name} (${selectedCustomSlot!.displayTime})'
                            : 'Enter tenant details below',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Form Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Phone Field (First)
                  _buildSectionLabel('Tenant Phone Number'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: phoneController,
                    decoration: _inputDecoration(
                      hint: '10-digit mobile number',
                      prefixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(width: 14),
                          const Icon(Icons.phone_rounded, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            '+91',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                              fontSize: 14,
                            ),
                          ),
                          Container(
                            height: 20,
                            width: 1,
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            color: Colors.grey.shade300,
                          ),
                        ],
                      ),
                    ),
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    enabled: !isSubmitting,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Phone number is required';
                      }
                      if (value.length != 10) {
                        return 'Enter a valid 10-digit number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // Name Field (Second - Auto-populated if tenant exists)
                  if (nameController != null) ...[
                    _buildSectionLabel('Tenant Name (Optional)'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: nameController,
                      decoration: _inputDecoration(
                        hint: 'Enter tenant name',
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(left: 14),
                          child: Icon(Icons.person_rounded, size: 18),
                        ),
                      ),
                      keyboardType: TextInputType.name,
                      enabled: !isSubmitting,
                      textCapitalization: TextCapitalization.words,
                      maxLength: 50,
                      validator: (value) {
                        // Optional field, but if provided, should be valid
                        if (value != null && value.trim().isNotEmpty) {
                          if (value.trim().length < 2) {
                            return 'Name must be at least 2 characters';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Payment Method Section
                  _buildSectionLabel('Payment Method'),
                  const SizedBox(height: 8),
                  _PaymentMethodSelector(
                    selectedMethod: paymentMethod ?? PaymentMode.cash,
                    enabled: !isSubmitting,
                    onChanged: onPaymentMethodChanged,
                  ),
                  const SizedBox(height: 12),

                  // Cash/UPI Toggle (only show for cash or UPI)
                  if (paymentMethod == PaymentMode.cash ||
                      paymentMethod == PaymentMode.upi) ...[
                    Row(
                      children: [
                        Checkbox(
                          value: markCashReceived,
                          onChanged: isSubmitting
                              ? null
                              : (value) {
                                  onMarkCashReceivedChanged?.call(
                                    value ?? false,
                                  );
                                },
                          activeColor: const Color(0xFF10B981),
                        ),
                        Expanded(
                          child: Text(
                            'Mark rent as received (activate bed immediately)',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Start Date Field
                  if (onStartDateChanged != null) ...[
                    _buildSectionLabel('Start Date (Optional)'),
                    const SizedBox(height: 8),
                    _DateField(
                      value: startDate ?? DateTime.now(),
                      enabled: !isSubmitting,
                      onChanged: onStartDateChanged!,
                      allowPastDates: true,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Custom Duration Toggle
                  if (onUseCustomDurationChanged != null) ...[
                    Row(
                      children: [
                        Checkbox(
                          value: useCustomDuration,
                          onChanged: isSubmitting
                              ? null
                              : (value) {
                                  onUseCustomDurationChanged?.call(
                                    value ?? false,
                                  );
                                },
                          activeColor: const Color(0xFF10B981),
                        ),
                        Expanded(
                          child: Text(
                            'Use custom duration (override plan)',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Custom Duration Fields (shown when enabled)
                  if (useCustomDuration &&
                      onCustomDurationDaysChanged != null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionLabel('Duration (Days)'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller:
                                    customDurationDaysController ??
                                    TextEditingController(
                                      text:
                                          customDurationDays?.toString() ?? '',
                                    ),
                                keyboardType: TextInputType.number,
                                enabled: !isSubmitting,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: _inputDecoration(hint: 'e.g., 15'),
                                validator: (value) {
                                  if (useCustomDuration &&
                                      customDurationMonths == null &&
                                      (value == null || value.isEmpty)) {
                                    return 'Required';
                                  }
                                  if (value != null && value.isNotEmpty) {
                                    final days = int.tryParse(value);
                                    if (days == null || days <= 0) {
                                      return 'Must be > 0';
                                    }
                                  }
                                  return null;
                                },
                                onChanged: (value) {
                                  if (value.isEmpty) {
                                    onCustomDurationDaysChanged?.call(null);
                                    return;
                                  }
                                  final days = int.tryParse(value);
                                  onCustomDurationDaysChanged?.call(
                                    days != null && days > 0 ? days : null,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionLabel('Duration (Months)'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller:
                                    customDurationMonthsController ??
                                    TextEditingController(
                                      text:
                                          customDurationMonths?.toString() ??
                                          '',
                                    ),
                                keyboardType: TextInputType.number,
                                enabled: !isSubmitting,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: _inputDecoration(hint: 'e.g., 2'),
                                validator: (value) {
                                  if (useCustomDuration &&
                                      customDurationDays == null &&
                                      (value == null || value.isEmpty)) {
                                    return 'Required';
                                  }
                                  if (value != null && value.isNotEmpty) {
                                    final months = int.tryParse(value);
                                    if (months == null || months <= 0) {
                                      return 'Must be > 0';
                                    }
                                  }
                                  return null;
                                },
                                onChanged: (value) {
                                  if (value.isEmpty) {
                                    onCustomDurationMonthsChanged?.call(null);
                                    return;
                                  }
                                  final months = int.tryParse(value);
                                  onCustomDurationMonthsChanged?.call(
                                    months != null && months > 0
                                        ? months
                                        : null,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Stay Details Row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionLabel('Stay Plan'),
                            const SizedBox(height: 8),
                            _PlanDropdown(
                              value: selectedPlan,
                              enabled: !isSubmitting && !useCustomDuration,
                              onChanged: onPlanChanged,
                              showCustomDurationNote: useCustomDuration,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionLabel('Expires'),
                            const SizedBox(height: 8),
                            _DateField(
                              value: expiryDate,
                              enabled: !isSubmitting,
                              onChanged: onExpiryDateChanged,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Payment Details Section (moved to bottom as less frequently used)
                  if (paymentMethod == PaymentMode.cash ||
                      paymentMethod == PaymentMode.upi) ...[
                    const Divider(height: 32, color: Color(0xFFE2E8F0)),

                    // Payment Received Date (only show when cash is marked received)
                    if (markCashReceived) ...[
                      _buildSectionLabel('Payment Received Date'),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: isSubmitting
                            ? null
                            : () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate:
                                      paymentReceivedDate ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(),
                                  builder: (context, child) {
                                    return Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: const ColorScheme.light(
                                          primary: Color(0xFF10B981),
                                          onPrimary: Colors.white,
                                          surface: Colors.white,
                                          onSurface: Color(0xFF1E293B),
                                        ),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                                if (picked != null) {
                                  onPaymentReceivedDateChanged?.call(picked);
                                }
                              },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 18,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                DateFormat(
                                  'dd MMM yyyy',
                                ).format(paymentReceivedDate ?? DateTime.now()),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Discount Field
                    _buildSectionLabel('Discount (₹)'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: discountController,
                      keyboardType: TextInputType.number,
                      enabled: !isSubmitting,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}'),
                        ),
                      ],
                      decoration: _inputDecoration(hint: '0.00'),
                      validator: (value) {
                        final discount = double.tryParse(value ?? '0') ?? 0;
                        if (discount < 0) {
                          return 'Discount cannot be negative';
                        }
                        if (onCalculateTotalPrice != null) {
                          final totalPrice = onCalculateTotalPrice!();
                          if (discount > totalPrice) {
                            return 'Discount cannot exceed total price';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Partial Payment Toggle
                    Row(
                      children: [
                        Checkbox(
                          value: isPartialPayment,
                          onChanged: isSubmitting
                              ? null
                              : (value) {
                                  onPartialPaymentChanged?.call(value ?? false);
                                },
                          activeColor: const Color(0xFF10B981),
                        ),
                        Expanded(
                          child: Text(
                            'Partial rent received',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Partial Payment Fields (shown when enabled)
                    if (isPartialPayment && amountPaidController != null) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionLabel('Amount Paid (₹)'),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: amountPaidController,
                                  keyboardType: TextInputType.number,
                                  enabled: !isSubmitting,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'^\d+\.?\d{0,2}'),
                                    ),
                                  ],
                                  decoration: _inputDecoration(hint: '0.00'),
                                  validator: (value) {
                                    if (isPartialPayment &&
                                        (value == null || value.isEmpty)) {
                                      return 'Required';
                                    }
                                    final amount =
                                        double.tryParse(value ?? '0') ?? 0;
                                    if (amount < 0) {
                                      return 'Invalid amount';
                                    }
                                    if (isPartialPayment &&
                                        selectedCustomSlot != null) {
                                      final totalPrice =
                                          onCalculateTotalPrice!() -
                                          (double.tryParse(
                                                discountController?.text ?? '0',
                                              ) ??
                                              0);
                                      if (amount > totalPrice) {
                                        return 'Cannot exceed total price';
                                      }
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionLabel('Remaining (₹)'),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: amountRemainingController,
                                  keyboardType: TextInputType.number,
                                  enabled:
                                      false, // Read-only, calculated automatically
                                  decoration: _inputDecoration(hint: '0.00')
                                      .copyWith(
                                        fillColor: Colors.grey.shade100,
                                        hintStyle: TextStyle(
                                          color: Colors.grey.shade400,
                                          fontSize: 14,
                                        ),
                                      ),
                                  style: TextStyle(color: Colors.grey.shade700),
                                  validator: (value) {
                                    if (isPartialPayment &&
                                        (value == null || value.isEmpty)) {
                                      return 'Required';
                                    }
                                    final amount =
                                        double.tryParse(value ?? '0') ?? 0;
                                    if (amount < 0) {
                                      return 'Invalid amount';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (paymentNotesController != null) ...[
                        const SizedBox(height: 16),
                        _buildSectionLabel('Payment Notes (Optional)'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: paymentNotesController,
                          maxLines: 2,
                          enabled: !isSubmitting,
                          decoration: _inputDecoration(
                            hint: 'Add notes about partial rent...',
                          ),
                        ),
                      ],
                    ],
                  ],
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isSubmitting ? null : onCancel,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: isSubmitting ? null : onSubmit,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_rounded, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Assign',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Color(0xFF64748B),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint, Widget? prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      prefixIcon: prefixIcon,
      prefixIconConstraints: const BoxConstraints(minWidth: 0),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDC2626)),
      ),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      counterText: '',
    );
  }
}

class _PlanDropdown extends StatelessWidget {
  const _PlanDropdown({
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.showCustomDurationNote = false,
  });

  final MembershipPlan value;
  final bool enabled;
  final ValueChanged<MembershipPlan> onChanged;
  final bool showCustomDurationNote;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<MembershipPlan>(
              value: value,
              isExpanded: true,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              borderRadius: BorderRadius.circular(12),
              items: MembershipPlan.values.map((plan) {
                return DropdownMenuItem(
                  value: plan,
                  child: Text(
                    _planLabel(plan),
                    style: const TextStyle(fontSize: 14),
                  ),
                );
              }).toList(),
              onChanged: enabled
                  ? (plan) {
                      if (plan != null) onChanged(plan);
                    }
                  : null,
            ),
          ),
        ),
        if (showCustomDurationNote) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: Colors.blue.shade600,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Custom duration will override plan duration',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue.shade700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  String _planLabel(MembershipPlan plan) {
    return plan.displayLabel;
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.allowPastDates = false,
  });

  final DateTime value;
  final bool enabled;
  final ValueChanged<DateTime> onChanged;
  final bool allowPastDates;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('MMM dd');

    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled
            ? () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: value,
                  firstDate: allowPastDates
                      ? DateTime.now().subtract(const Duration(days: 365))
                      : DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) {
                  onChanged(picked);
                }
              }
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  formatter.format(value),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              Icon(
                Icons.calendar_today_rounded,
                size: 16,
                color: Colors.grey.shade500,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentMethodSelector extends StatelessWidget {
  const _PaymentMethodSelector({
    required this.selectedMethod,
    required this.enabled,
    this.onChanged,
  });

  final PaymentMode selectedMethod;
  final bool enabled;
  final ValueChanged<PaymentMode?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Expanded(
            child: _PaymentMethodButton(
              method: PaymentMode.upi,
              label: 'UPI',
              icon: Icons.qr_code_rounded,
              isSelected: selectedMethod == PaymentMode.upi,
              enabled: enabled,
              onTap: () => onChanged?.call(PaymentMode.upi),
            ),
          ),
          Container(width: 1, height: 40, color: Colors.grey.shade300),
          Expanded(
            child: _PaymentMethodButton(
              method: PaymentMode.cash,
              label: 'Cash',
              icon: Icons.money_rounded,
              isSelected: selectedMethod == PaymentMode.cash,
              enabled: enabled,
              onTap: () => onChanged?.call(PaymentMode.cash),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodButton extends StatelessWidget {
  const _PaymentMethodButton({
    required this.method,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.enabled,
    required this.onTap,
  });

  final PaymentMode method;
  final String label;
  final IconData icon;
  final bool isSelected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? const Color(0xFF10B981).withValues(alpha: 0.1)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? const Color(0xFF10B981)
                    : Colors.grey.shade600,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? const Color(0xFF10B981)
                      : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated wrapper for fade+slide entrance animation.
class AnimatedFadeSlide extends StatefulWidget {
  const AnimatedFadeSlide({super.key, required this.child});

  final Widget child;

  @override
  State<AnimatedFadeSlide> createState() => _AnimatedFadeSlideState();
}

class _AnimatedFadeSlideState extends State<AnimatedFadeSlide>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(position: _slideAnimation, child: widget.child),
    );
  }
}
