import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/referral.dart';
import '../../core/app_ui_constants.dart';
import '../../core/widgets/premium_kit.dart';
import '../cubit/withdrawal_approval_cubit.dart';
import '../widgets/subscription_widgets/shimmer_box.dart';

class AdminWithdrawalApprovalsScreen extends StatelessWidget {
  const AdminWithdrawalApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUIConstants.background,
      appBar: AppBar(
        title: const Text(
          'Referral Withdrawals',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: AppUIConstants.background,
        foregroundColor: AppUIConstants.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
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
          final Widget child;
          if (state.isLoading && state.pendingRequests.isEmpty) {
            child = ListView(
              key: const ValueKey('loading'),
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 16),
              children: List.generate(4, (_) => const ShimmerCardRow()),
            );
          } else if (state.pendingRequests.isEmpty) {
            child = const AdminEmptyState(
              key: ValueKey('empty'),
              icon: Icons.verified_rounded,
              color: AppUIConstants.primaryLight,
              title: 'All caught up',
              message: 'No pending withdrawal requests right now',
            );
          } else {
            final total = state.pendingRequests.fold<double>(
              0,
              (sum, r) => sum + r.amount,
            );
            child = Column(
              key: const ValueKey('list'),
              children: [
                _Hero(total: total, count: state.pendingRequests.length),
                Expanded(
                  child: RefreshIndicator(
                    color: AppUIConstants.primaryLight,
                    backgroundColor: AppUIConstants.surface,
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
                  ),
                ),
              ],
            );
          }
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: child,
          );
        },
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.total, required this.count});

  final double total;
  final int count;

  @override
  Widget build(BuildContext context) {
    return PremiumHero(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PENDING PAYOUTS',
            style: TextStyle(
              color: AppUIConstants.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '₹${NumberFormat('#,##,##0', 'en_IN').format(total)}',
            style: const TextStyle(
              color: AppUIConstants.textPrimary,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const PremiumStatusPill('Pending', color: AppUIConstants.warning),
              const SizedBox(width: 8),
              Text(
                '$count request${count == 1 ? '' : 's'} awaiting review',
                style: const TextStyle(
                  color: AppUIConstants.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
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

    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppUIConstants.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: AppUIConstants.primaryLight,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '₹${request.amount.toStringAsFixed(0)}',
                  style: AppUIConstants.headingMd,
                ),
              ),
              const PremiumStatusPill('Pending', color: AppUIConstants.warning),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppUIConstants.surfaceMuted,
              borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
            ),
            child: Column(
              children: [
                _infoRow(
                  Icons.person_outline_rounded,
                  'Owner ID',
                  request.ownerId,
                ),
                if (request.upiId != null && request.upiId!.isNotEmpty)
                  _infoRow(Icons.qr_code_rounded, 'UPI ID', request.upiId!),
                _infoRow(Icons.schedule_rounded, 'Requested', dateStr),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showRejectDialog(context),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppUIConstants.error,
                    side: BorderSide(
                      color: AppUIConstants.error.withValues(alpha: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppUIConstants.radiusSm,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () => context
                      .read<WithdrawalApprovalCubit>()
                      .approve(request.id),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Approve'),
                  style: AppUIConstants.primaryButtonStyle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppUIConstants.textTertiary),
          const SizedBox(width: 8),
          SizedBox(
            width: 78,
            child: Text(label, style: AppUIConstants.caption),
          ),
          Expanded(
            child: Text(
              value,
              style: AppUIConstants.bodySm.copyWith(
                color: AppUIConstants.textPrimary,
              ),
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
