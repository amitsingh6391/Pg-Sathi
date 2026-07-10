import 'package:flutter/material.dart';

import '../../../../domain/entities/subscription_plan.dart';
import '../../../core/app_ui_constants.dart';

class CustomPricingResult {
  const CustomPricingResult({this.newPrice, this.clearPrice = false});
  final double? newPrice;
  final bool clearPrice;
}

Future<CustomPricingResult?> showEditCustomPricingSheet({
  required BuildContext context,
  double? currentPrice,
  required String libraryName,
  required int libraryCapacity,
}) {
  return showModalBottomSheet<CustomPricingResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: EditCustomPricingSheet(
          currentPrice: currentPrice,
          libraryName: libraryName,
          libraryCapacity: libraryCapacity,
        ),
      );
    },
  );
}

class EditCustomPricingSheet extends StatefulWidget {
  const EditCustomPricingSheet({
    super.key,
    this.currentPrice,
    required this.libraryName,
    required this.libraryCapacity,
  });

  final double? currentPrice;
  final String libraryName;
  final int libraryCapacity;

  @override
  State<EditCustomPricingSheet> createState() => _EditCustomPricingSheetState();
}

class _EditCustomPricingSheetState extends State<EditCustomPricingSheet> {
  late final TextEditingController _priceController;
  bool _clearPrice = false;
  late final double _defaultPrice;
  late final String _defaultPlanName;

  @override
  void initState() {
    super.initState();

    // Calculate default tier pricing based on capacity
    final plan = SubscriptionPlan.getPlanForSeats(widget.libraryCapacity);
    _defaultPrice = plan.monthlyPrice;
    _defaultPlanName = plan.name;

    _priceController = TextEditingController(
      text: widget.currentPrice?.toStringAsFixed(0) ?? '',
    );
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  void _handleSave() {
    if (!mounted) return;

    if (_clearPrice) {
      Navigator.of(
        context,
      ).pop<CustomPricingResult>(const CustomPricingResult(clearPrice: true));
      return;
    }

    final text = _priceController.text.trim();
    final value = double.tryParse(text);

    if (text.isEmpty || value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid price greater than 0'),
          backgroundColor: AppUIConstants.error,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    Navigator.of(
      context,
    ).pop<CustomPricingResult>(CustomPricingResult(newPrice: value));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppUIConstants.spacingLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppUIConstants.border,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: AppUIConstants.spacingMd),

                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppUIConstants.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.price_change_rounded,
                        color: AppUIConstants.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppUIConstants.spacingMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Set Custom Pricing',
                            style: AppUIConstants.headingSm.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'For: ${widget.libraryName}',
                            style: AppUIConstants.bodySm.copyWith(
                              color: AppUIConstants.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppUIConstants.spacingLg),

                // Price input
                TextField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  enabled: !_clearPrice,
                  readOnly: _clearPrice,
                  decoration: InputDecoration(
                    labelText: _clearPrice
                        ? 'Default Tier Price (Read-only)'
                        : 'Monthly Subscription Price (₹)',
                    hintText: _clearPrice ? null : 'e.g. 299',
                    prefixIcon: const Icon(Icons.currency_rupee),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppUIConstants.radiusMd,
                      ),
                    ),
                    filled: _clearPrice,
                    fillColor: _clearPrice ? AppUIConstants.background : null,
                    suffixIcon: _clearPrice
                        ? Container(
                            margin: const EdgeInsets.all(8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppUIConstants.success.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _defaultPlanName,
                              style: AppUIConstants.caption.copyWith(
                                color: AppUIConstants.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : null,
                  ),
                  onChanged: (_) => setState(() => _clearPrice = false),
                ),
                const SizedBox(height: AppUIConstants.spacingMd),

                // Clear price checkbox
                Container(
                  padding: const EdgeInsets.all(AppUIConstants.spacingSm),
                  decoration: BoxDecoration(
                    color: AppUIConstants.background,
                    borderRadius: BorderRadius.circular(
                      AppUIConstants.radiusMd,
                    ),
                    border: Border.all(color: AppUIConstants.border),
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _clearPrice,
                        onChanged: (v) {
                          setState(() {
                            _clearPrice = v ?? false;
                            if (_clearPrice) {
                              _priceController.text = _defaultPrice
                                  .toStringAsFixed(0);
                            } else {
                              _priceController.text =
                                  widget.currentPrice?.toStringAsFixed(0) ?? '';
                            }
                          });
                        },
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Clear custom price (revert to default tier pricing)',
                              overflow: TextOverflow.visible,
                            ),
                            if (_clearPrice) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Will use $_defaultPlanName plan (₹$_defaultPrice/month)',
                                style: AppUIConstants.caption.copyWith(
                                  color: AppUIConstants.success,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppUIConstants.spacingLg),

                // Info box
                Container(
                  padding: const EdgeInsets.all(AppUIConstants.spacingMd),
                  decoration: BoxDecoration(
                    color: AppUIConstants.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(
                      AppUIConstants.radiusMd,
                    ),
                    border: Border.all(
                      color: AppUIConstants.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppUIConstants.primary,
                        size: 20,
                      ),
                      const SizedBox(width: AppUIConstants.spacingMd),
                      Expanded(
                        child: Text(
                          _clearPrice
                              ? 'Default tier pricing is based on library capacity (${widget.libraryCapacity} seats → $_defaultPlanName plan).'
                              : 'Custom pricing overrides the default tier pricing for this library.',
                          style: AppUIConstants.bodySm.copyWith(
                            color: AppUIConstants.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppUIConstants.spacingLg),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            Navigator.of(context).pop<CustomPricingResult>(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppUIConstants.textPrimary,
                          side: BorderSide(color: AppUIConstants.border),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: AppUIConstants.spacingSm),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppUIConstants.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                        child: const Text('Save Changes'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
