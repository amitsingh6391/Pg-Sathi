import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/referral.dart';
import '../../core/app_ui_constants.dart';
import '../cubit/withdrawal_approval_cubit.dart';

class AdminWithdrawalApprovalsScreen extends StatelessWidget {
  const AdminWithdrawalApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUIConstants.background,
      appBar: AppBar(
        title: const Text('Referral Withdrawals'),
        backgroundColor: AppUIConstants.surface,
        foregroundColor: AppUIConstants.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      body: BlocConsumer<WithdrawalApprovalCubit, WithdrawalApprovalState>(
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: AppUIConstants.error,
              ),
            );
          }
          if (state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.successMessage!),
                backgroundColor: AppUIConstants.success,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state.isLoading && state.pendingRequests.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }

          if (state.pendingRequests.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: () =>
                context.read<WithdrawalApprovalCubit>().load(),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppUIConstants.spacingLg),
              itemCount: state.pendingRequests.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _WithdrawalCard(
                request: state.pendingRequests[index],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 48,
            color: AppUIConstants.textSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            'No pending withdrawal requests',
            style: AppUIConstants.bodyMd,
          ),
        ],
      ),
    );
  }
}

class _WithdrawalCard extends StatelessWidget {
  const _WithdrawalCard({required this.request});

  final WithdrawalRequest request;

  @override
  Widget build(BuildContext context) {
    final dateStr = request.createdAt != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(request.createdAt!)
        : 'Unknown date';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppUIConstants.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet_rounded,
                color: AppUIConstants.warning,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '₹${request.amount.toStringAsFixed(0)}',
                  style: AppUIConstants.headingMd,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppUIConstants.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'PENDING',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppUIConstants.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _infoRow('Owner ID', request.ownerId),
          if (request.upiId != null && request.upiId!.isNotEmpty)
            _infoRow('UPI ID', request.upiId!),
          _infoRow('Requested', dateStr),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _showRejectDialog(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppUIConstants.error,
                    side: BorderSide(
                      color: AppUIConstants.error.withValues(alpha: 0.3),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppUIConstants.radiusSm,
                      ),
                    ),
                  ),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => context
                      .read<WithdrawalApprovalCubit>()
                      .approve(request.id),
                  style: AppUIConstants.primaryButtonStyle,
                  child: const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: AppUIConstants.caption),
          ),
          Expanded(
            child: Text(
              value,
              style: AppUIConstants.bodySm,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppUIConstants.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        ),
        title: Text('Reject Withdrawal', style: AppUIConstants.headingMd),
        content: TextField(
          controller: reasonController,
          decoration: InputDecoration(
            labelText: 'Reason',
            hintText: 'e.g. Invalid UPI ID',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
            ),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppUIConstants.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<WithdrawalApprovalCubit>().reject(
                    request.id,
                    reasonController.text.trim().isNotEmpty
                        ? reasonController.text.trim()
                        : 'Rejected by admin',
                  );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppUIConstants.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
              ),
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }
}
