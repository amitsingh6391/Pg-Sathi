import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../domain/entities/payment.dart';
import '../../../../domain/usecases/get_occupied_seats.dart';

/// Bottom sheet for marking pending tenant rent as received.
/// Supports full rent, partial rent, and discount.
class ConvertPaymentBottomSheet extends StatefulWidget {
  const ConvertPaymentBottomSheet({
    super.key,
    required this.seatInfo,
    required this.fullAmount,
    required this.existingPaid,
    required this.existingRemaining,
    required this.existingDiscount,
    required this.hasExistingPartial,
    required this.onConvert,
  });

  final OccupiedSeatInfo seatInfo;
  final double fullAmount;
  final double existingPaid;
  final double existingRemaining;
  final double existingDiscount;
  final bool hasExistingPartial;
  final void Function(
    double amountPaid,
    bool isPartial,
    String? notes,
    double discount,
    PaymentMode paymentMethod,
  )
  onConvert;

  @override
  State<ConvertPaymentBottomSheet> createState() =>
      _ConvertPaymentBottomSheetState();
}

class _ConvertPaymentBottomSheetState extends State<ConvertPaymentBottomSheet> {
  final _amountPaidController = TextEditingController();
  final _notesController = TextEditingController();
  final _discountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isPartialPayment = false;
  double _calculatedRemaining = 0.0;
  double _discount = 0.0;
  late PaymentMode _selectedPaymentMethod;

  @override
  void initState() {
    super.initState();
    _selectedPaymentMethod =
        widget.seatInfo.membership.paymentMethod == PaymentMode.upi
        ? PaymentMode.upi
        : PaymentMode.cash;

    // Pre-fill discount if it exists (do this first to get the correct amount)
    if (widget.existingDiscount > 0) {
      _discountController.text = widget.existingDiscount.toStringAsFixed(0);
      _discount = widget.existingDiscount;
    }

    // Calculate discounted amount
    final discountedAmount = (widget.fullAmount - _discount).clamp(
      0.0,
      double.infinity,
    );

    // For existing partial rent, pre-fill with remaining amount to complete.
    // This makes it easy to complete the rent payment.
    if (widget.hasExistingPartial && widget.existingPaid > 0) {
      // Pre-fill with remaining amount to make completion easier
      _amountPaidController.text = widget.existingRemaining.toStringAsFixed(0);
      _calculatedRemaining = 0.0; // Will complete if they keep this value
      _isPartialPayment = false; // Will be full if they keep this value
    } else {
      // For new payments, pre-fill with discounted amount (not original amount)
      _amountPaidController.text = discountedAmount.toStringAsFixed(0);
      _calculatedRemaining = 0.0;
      _isPartialPayment = false;
    }

    _amountPaidController.addListener(_calculateRemaining);
    _discountController.addListener(_onDiscountChanged);
  }

  @override
  void dispose() {
    _amountPaidController.dispose();
    _notesController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  void _onDiscountChanged() {
    // When discount changes, update the amount paid field to reflect new discounted total
    // Only do this if user hasn't manually changed the amount (i.e., remaining is 0)
    if (_calculatedRemaining == 0.0 && !widget.hasExistingPartial) {
      final discount = double.tryParse(_discountController.text) ?? 0.0;
      final discountedAmount = (widget.fullAmount - discount).clamp(
        0.0,
        double.infinity,
      );
      _amountPaidController.text = discountedAmount.toStringAsFixed(0);
    } else {
      // Just recalculate remaining
      _calculateRemaining();
    }
  }

  void _calculateRemaining() {
    final newPayment = double.tryParse(_amountPaidController.text) ?? 0.0;
    final discount = double.tryParse(_discountController.text) ?? 0.0;
    final amountAfterDiscount = (widget.fullAmount - discount).clamp(
      0.0,
      double.infinity,
    );

    setState(() {
      _discount = discount;

      // For partial payments, calculate: remaining = total - (existing + new)
      // For new payments, calculate: remaining = total - new
      final totalPaid = widget.hasExistingPartial
          ? (widget.existingPaid + newPayment)
          : newPayment;

      _calculatedRemaining = (amountAfterDiscount - totalPaid).clamp(
        0.0,
        double.infinity,
      );

      if (_calculatedRemaining <= 0) {
        _isPartialPayment = false;
        _calculatedRemaining = 0.0;
      } else {
        _isPartialPayment = true;
      }
    });
  }

  double get _finalAmount =>
      (widget.fullAmount - _discount).clamp(0.0, double.infinity);

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.85;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDragHandle(),
                _buildHeader(),
                _buildContent(),
                _buildActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDragHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.payment_rounded,
              color: Colors.green.shade700,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mark Rent Received',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.seatInfo.displayName,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).pop(),
            color: Colors.grey.shade600,
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Flexible(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTotalAmountCard(),
            const SizedBox(height: 16),
            _buildDiscountField(),
            const SizedBox(height: 16),
            // Show existing payment info for partial payments
            if (widget.hasExistingPartial) ...[
              _buildExistingPartialInfo(),
              const SizedBox(height: 16),
            ],
            _buildAmountInput(),
            const SizedBox(height: 12),
            _buildPaymentMethodSelector(),
            const SizedBox(height: 12),
            // Payment Summary
            if (_amountPaidController.text.isNotEmpty || _discount > 0)
              _buildPaymentSummary(),
            const SizedBox(height: 16),
            _buildNotesInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalAmountCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.account_balance_wallet_rounded,
            color: Colors.blue.shade700,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Rent',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_discount > 0 || widget.existingDiscount > 0) ...[
                      Text(
                        '₹${widget.fullAmount.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 14,
                          decoration: TextDecoration.lineThrough,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${_finalAmount.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ] else
                      Text(
                        '₹${widget.fullAmount.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Discount (₹)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _discountController,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: '0.00',
            suffixText: '₹',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
          ],
          validator: (value) {
            final discount = double.tryParse(value ?? '0') ?? 0.0;
            if (discount < 0) {
              return 'Discount cannot be negative';
            }
            if (discount > widget.fullAmount) {
              return 'Discount cannot exceed total amount';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildExistingPartialInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: Colors.orange.shade700,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Partial Rent in Progress',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Already paid: ₹${widget.existingPaid.toStringAsFixed(0)} • Remaining: ₹${widget.existingRemaining.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSelector() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Paid via',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SegmentedButton<PaymentMode>(
            style: SegmentedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
            showSelectedIcon: false,
            segments: const [
              ButtonSegment<PaymentMode>(
                value: PaymentMode.cash,
                label: Text('Cash'),
                icon: Icon(Icons.payments_outlined, size: 16),
              ),
              ButtonSegment<PaymentMode>(
                value: PaymentMode.upi,
                label: Text('UPI'),
                icon: Icon(Icons.qr_code_2_rounded, size: 16),
              ),
            ],
            selected: {_selectedPaymentMethod},
            onSelectionChanged: (Set<PaymentMode> selection) {
              if (selection.isEmpty) return;
              setState(() => _selectedPaymentMethod = selection.first);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAmountInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.hasExistingPartial ? 'New Rent Amount' : 'Rent Received',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _amountPaidController,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: widget.hasExistingPartial
                ? 'Enter new rent amount'
                : 'Enter rent received',
            prefixIcon: const Icon(Icons.currency_rupee_rounded),
            suffixText: '₹',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
          ],
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter amount';
            }
            final amount = double.tryParse(value) ?? 0.0;
            if (amount <= 0) {
              return 'Amount must be greater than 0';
            }
            // For partial rent, cannot exceed remaining amount.
            // For new rent, cannot exceed final amount.
            final maxAllowed = widget.hasExistingPartial
                ? widget.existingRemaining
                : _finalAmount;
            if (amount > maxAllowed) {
              return widget.hasExistingPartial
                  ? 'Cannot exceed remaining amount (₹${maxAllowed.toStringAsFixed(0)})'
                  : 'Cannot exceed final amount';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPaymentSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          if (_discount > 0) ...[
            _buildSummaryRow(
              'Original Amount',
              '₹${widget.fullAmount.toStringAsFixed(0)}',
              strikeThrough: true,
            ),
            const SizedBox(height: 8),
            _buildSummaryRow(
              'Discount',
              '-₹${_discount.toStringAsFixed(0)}',
              valueColor: Colors.green.shade700,
              isBold: true,
            ),
            const SizedBox(height: 8),
            _buildSummaryRow(
              'Final Amount',
              '₹${_finalAmount.toStringAsFixed(0)}',
              isBold: true,
              valueFontSize: 16,
            ),
            const Divider(height: 20),
          ],
          // Show breakdown for partial payments
          if (widget.hasExistingPartial) ...[
            _buildSummaryRow(
              'Already Paid',
              '₹${widget.existingPaid.toStringAsFixed(0)}',
            ),
            const SizedBox(height: 8),
            _buildSummaryRow(
              'New Rent',
              '₹${(double.tryParse(_amountPaidController.text) ?? 0.0).toStringAsFixed(0)}',
            ),
            const Divider(height: 20),
            _buildSummaryRow(
              'Total Paid',
              '₹${(widget.existingPaid + (double.tryParse(_amountPaidController.text) ?? 0.0)).toStringAsFixed(0)}',
              isBold: true,
              valueFontSize: 16,
            ),
          ] else
            _buildSummaryRow(
              'Amount Paid',
              '₹${(double.tryParse(_amountPaidController.text) ?? 0.0).toStringAsFixed(0)}',
              isBold: false,
              valueFontSize: 16,
            ),
          if (_isPartialPayment) ...[
            const Divider(height: 20),
            _buildSummaryRow(
              'Remaining',
              '₹${_calculatedRemaining.toStringAsFixed(0)}',
              isBold: true,
              valueFontSize: 16,
            ),
            const SizedBox(height: 8),
            _buildInfoNote(
              Icons.info_outline_rounded,
              'Partial rent - Stay remains active with remaining balance',
            ),
          ] else ...[
            const SizedBox(height: 8),
            _buildInfoNote(
              Icons.check_circle_rounded,
              'Full rent - Stay will be fully activated',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool strikeThrough = false,
    Color? valueColor,
    bool isBold = false,
    double valueFontSize = 14,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
            color: Colors.grey.shade700,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: valueFontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color:
                valueColor ??
                (strikeThrough ? Colors.grey.shade500 : Colors.grey.shade900),
            decoration: strikeThrough ? TextDecoration.lineThrough : null,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoNote(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notes (Optional)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _notesController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Add any notes about this rent payment...',
            prefixIcon: const Icon(Icons.note_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade900,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  if (_formKey.currentState?.validate() ?? false) {
                    final amountPaid =
                        double.tryParse(_amountPaidController.text) ?? 0.0;
                    final notes = _notesController.text.trim().isEmpty
                        ? null
                        : _notesController.text.trim();
                    final discount =
                        double.tryParse(_discountController.text) ?? 0.0;
                    widget.onConvert(
                      amountPaid,
                      _isPartialPayment,
                      notes,
                      discount,
                      _selectedPaymentMethod,
                    );
                  }
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _isPartialPayment
                            ? 'Mark Partial'
                            : (widget.hasExistingPartial
                                  ? 'Complete Rent'
                                  : 'Mark Full'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
