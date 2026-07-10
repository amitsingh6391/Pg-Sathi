import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/coupon.dart';
import '../../core/app_ui_constants.dart';
import '../cubit/admin_cubit.dart';

/// Screen for managing coupon codes.
class CouponManagementScreen extends StatelessWidget {
  const CouponManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUIConstants.background,
      appBar: AppBar(
        title: const Text('Manage Coupons'),
        backgroundColor: AppUIConstants.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateCouponDialog(context),
        backgroundColor: AppUIConstants.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: BlocBuilder<AdminCubit, AdminState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.coupons.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.discount_outlined,
                    color: AppUIConstants.textTertiary,
                    size: 64,
                  ),
                  const SizedBox(height: AppUIConstants.spacingLg),
                  Text('No coupons yet', style: AppUIConstants.headingSm),
                  const SizedBox(height: AppUIConstants.spacingSm),
                  Text(
                    'Create your first coupon to offer discounts',
                    style: AppUIConstants.bodyMd,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppUIConstants.spacingLg),
            itemCount: state.coupons.length,
            itemBuilder: (context, index) {
              return _buildCouponCard(state.coupons[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildCouponCard(Coupon coupon) {
    final isValid = coupon.isValid(DateTime.now());

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppUIConstants.spacingMd),
      padding: const EdgeInsets.all(AppUIConstants.spacingLg),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        border: Border.all(
          color: isValid
              ? AppUIConstants.success.withValues(alpha: 0.3)
              : AppUIConstants.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppUIConstants.spacingMd,
                  vertical: AppUIConstants.spacingSm,
                ),
                decoration: BoxDecoration(
                  color: AppUIConstants.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
                ),
                child: Text(
                  coupon.code,
                  style: AppUIConstants.headingSm.copyWith(
                    color: AppUIConstants.primary,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppUIConstants.spacingSm,
                  vertical: AppUIConstants.spacingXs,
                ),
                decoration: BoxDecoration(
                  color: isValid
                      ? AppUIConstants.success.withValues(alpha: 0.1)
                      : AppUIConstants.textTertiary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(
                    AppUIConstants.radiusFull,
                  ),
                ),
                child: Text(
                  isValid ? 'Active' : 'Inactive',
                  style: AppUIConstants.bodySm.copyWith(
                    color: isValid
                        ? AppUIConstants.success
                        : AppUIConstants.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppUIConstants.spacingMd),
          Row(
            children: [
              _buildInfoChip(
                Icons.percent,
                '${coupon.discountPercent.toStringAsFixed(0)}% off',
              ),
              const SizedBox(width: AppUIConstants.spacingMd),
              if (coupon.maxUses != null)
                _buildInfoChip(
                  Icons.people_outline,
                  '${coupon.currentUses}/${coupon.maxUses} uses',
                ),
            ],
          ),
          if (coupon.description != null) ...[
            const SizedBox(height: AppUIConstants.spacingMd),
            Text(coupon.description!, style: AppUIConstants.bodySm),
          ],
          if (coupon.validUntil != null) ...[
            const SizedBox(height: AppUIConstants.spacingSm),
            Text(
              'Valid until: ${_formatDate(coupon.validUntil!)}',
              style: AppUIConstants.bodySm.copyWith(
                color: AppUIConstants.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppUIConstants.spacingMd,
        vertical: AppUIConstants.spacingSm,
      ),
      decoration: BoxDecoration(
        color: AppUIConstants.background,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
        border: Border.all(color: AppUIConstants.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppUIConstants.textSecondary),
          const SizedBox(width: AppUIConstants.spacingXs),
          Text(label, style: AppUIConstants.bodySm),
        ],
      ),
    );
  }

  void _showCreateCouponDialog(BuildContext context) {
    final codeController = TextEditingController();
    final discountController = TextEditingController();
    final descriptionController = TextEditingController();
    final maxUsesController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppUIConstants.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        ),
        title: const Text('Create Coupon'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: codeController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Coupon Code',
                  hintText: 'e.g., SAVE20',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppUIConstants.radiusMd,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppUIConstants.spacingMd),
              TextField(
                controller: discountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Discount %',
                  hintText: 'e.g., 20',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppUIConstants.radiusMd,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppUIConstants.spacingMd),
              TextField(
                controller: descriptionController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppUIConstants.radiusMd,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppUIConstants.spacingMd),
              TextField(
                controller: maxUsesController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Max Uses (optional)',
                  hintText: 'Leave empty for unlimited',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppUIConstants.radiusMd,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final code = codeController.text.trim();
              final discount = double.tryParse(discountController.text) ?? 0;

              if (code.isEmpty || discount <= 0) return;

              context.read<AdminCubit>().addCoupon(
                code: code,
                discountPercent: discount,
                description: descriptionController.text.isEmpty
                    ? null
                    : descriptionController.text,
                maxUses: int.tryParse(maxUsesController.text),
              );
              Navigator.of(dialogContext).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppUIConstants.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
