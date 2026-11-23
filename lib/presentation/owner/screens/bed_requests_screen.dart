import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/di/injection_container.dart';
import '../../../domain/entities/payment.dart';
import '../../../domain/entities/library.dart';
import '../../../domain/entities/membership.dart';
import '../../core/app_ui_constants.dart';
import '../../core/widgets/premium_kit.dart';
import '../cubit/pending_approval_cubit.dart';

/// Owner screen listing resident bed requests (memberships awaiting approval)
/// with approve / reject actions.
class BedRequestsScreen extends StatelessWidget {
  const BedRequestsScreen({super.key, required this.library});

  final Library library;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          sl<PendingApprovalCubit>()
            ..loadPendingApprovals(library.id, ownerId: library.ownerId),
      child: _BedRequestsView(library: library),
    );
  }
}

class _BedRequestsView extends StatelessWidget {
  const _BedRequestsView({required this.library});

  final Library library;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUIConstants.background,
      appBar: AppBar(title: const Text('Bed requests')),
      body: BlocConsumer<PendingApprovalCubit, PendingApprovalState>(
        listener: (context, state) {
          final messenger = ScaffoldMessenger.of(context);
          if (state.errorMessage != null) {
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage!),
                  backgroundColor: AppUIConstants.error,
                ),
              );
          } else if (state.infoMessage != null) {
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(state.infoMessage!)));
          }
        },
        builder: (context, state) {
          if (state.status == PendingApprovalStatus.loading &&
              state.memberships.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppUIConstants.primaryLight,
              ),
            );
          }
          if (state.status == PendingApprovalStatus.error &&
              state.memberships.isEmpty) {
            return _Message(
              icon: Icons.error_outline_rounded,
              title: 'Could not load requests',
              body: state.errorMessage ?? 'Please try again.',
              actionLabel: 'Retry',
              onAction: () => context
                  .read<PendingApprovalCubit>()
                  .loadPendingApprovals(library.id),
            );
          }
          if (state.memberships.isEmpty) {
            return const _Message(
              icon: Icons.bed_outlined,
              title: 'No pending requests',
              body:
                  'When a resident requests a bed through your QR, it will '
                  'show up here for approval.',
            );
          }
          return RefreshIndicator(
            color: AppUIConstants.primaryLight,
            onRefresh: () => context
                .read<PendingApprovalCubit>()
                .loadPendingApprovals(library.id),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppUIConstants.spacingLg),
              itemCount: state.memberships.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppUIConstants.spacingMd),
              itemBuilder: (context, i) {
                final m = state.memberships[i];
                return _RequestCard(
                  membership: m,
                  library: library,
                  name:
                      state.userNames[m.userId] ??
                      ((m.studentName?.isNotEmpty ?? false)
                          ? m.studentName!
                          : m.phoneNumber),
                  slotName: state.slotNames[m.slotId],
                  slotPrice: state.slotPrices[m.slotId],
                  busy: state.processingIds.contains(m.id),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.membership,
    required this.library,
    required this.name,
    required this.busy,
    this.slotName,
    this.slotPrice,
  });

  final Membership membership;
  final Library library;
  final String name;
  final String? slotName;
  final double? slotPrice;
  final bool busy;

  double? get _amount {
    final total = membership.paymentBreakdown?.totalAmount ?? 0;
    if (total > 0) return total;
    if (slotPrice != null && slotPrice! > 0) {
      return slotPrice! * (membership.effectiveDurationInDays / 30.0);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final created = membership.createdAt;
    final amount = _amount;
    final dateFmt = DateFormat('d MMM');

    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppUIConstants.spacingLg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppUIConstants.surfaceMuted,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: AppUIConstants.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AppUIConstants.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppUIConstants.headingSm,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        membership.phoneNumber,
                        style: AppUIConstants.bodySm,
                      ),
                      if (created != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Requested ${DateFormat('d MMM, h:mm a').format(created)}',
                          style: AppUIConstants.caption,
                        ),
                      ],
                    ],
                  ),
                ),
                if (amount != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${amount.toStringAsFixed(0)}',
                        style: AppUIConstants.headingMd,
                      ),
                      const Text('rent', style: AppUIConstants.caption),
                    ],
                  ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppUIConstants.spacingLg,
              vertical: AppUIConstants.spacingSm,
            ),
            decoration: const BoxDecoration(
              color: AppUIConstants.surfaceMuted,
              border: Border.symmetric(
                horizontal: BorderSide(color: AppUIConstants.border),
              ),
            ),
            child: Column(
              children: [
                if (membership.assignedSeatId != null)
                  _DetailRow(
                    'Bed',
                    membership.assignedSeatId!,
                    emphasize: true,
                  ),
                if (membership.slotId != null)
                  _DetailRow('Room type', slotName ?? '-'),
                _DetailRow('Stay', membership.planDisplayLabel),
                _DetailRow(
                  'Period',
                  '${dateFmt.format(membership.startDate)} - '
                      '${DateFormat('d MMM yyyy').format(membership.endDate)}',
                ),
                if (membership.paymentMethod != null)
                  _DetailRow(
                    'Payment',
                    membership.paymentMethod == PaymentMode.upi
                        ? 'UPI to you'
                        : 'Cash at PG',
                  ),
                if (membership.upiTransactionId != null)
                  _DetailRow(
                    'UPI ref.',
                    membership.upiTransactionId!,
                    emphasize: true,
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppUIConstants.spacingMd),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : () => _reject(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppUIConstants.error,
                      side: BorderSide(
                        color: AppUIConstants.error.withValues(alpha: 0.4),
                      ),
                      minimumSize: const Size.fromHeight(44),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: AppUIConstants.spacingMd),
                Expanded(
                  child: FilledButton(
                    onPressed: busy ? null : () => _approve(context, amount),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppUIConstants.primaryLight,
                      foregroundColor: AppUIConstants.background,
                      minimumSize: const Size.fromHeight(44),
                    ),
                    child: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Approve'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _approve(BuildContext context, double? amount) async {
    final cubit = context.read<PendingApprovalCubit>();
    final recordPayment = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppUIConstants.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppUIConstants.radiusXl),
        ),
      ),
      builder: (_) => _ApproveSheet(
        name: name,
        bed: membership.assignedSeatId,
        amount: amount,
      ),
    );
    if (recordPayment == null) return;
    await cubit.approveMembership(
      membership: membership,
      libraryName: library.name,
      recordPayment: recordPayment,
    );
  }

  Future<void> _reject(BuildContext context) async {
    final cubit = context.read<PendingApprovalCubit>();
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppUIConstants.surface,
        title: const Text('Reject request?'),
        content: TextField(
          controller: controller,
          maxLines: 2,
          maxLength: 120,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Reason (optional, shown to the resident)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppUIConstants.error),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    final reason = controller.text.trim();
    controller.dispose();
    if (confirmed != true) return;
    await cubit.rejectMembership(
      membership: membership,
      libraryName: library.name,
      reason: reason.isEmpty ? null : reason,
    );
  }
}

class _ApproveSheet extends StatefulWidget {
  const _ApproveSheet({required this.name, this.bed, this.amount});

  final String name;
  final String? bed;
  final double? amount;

  @override
  State<_ApproveSheet> createState() => _ApproveSheetState();
}

class _ApproveSheetState extends State<_ApproveSheet> {
  bool _recordPayment = true;

  @override
  Widget build(BuildContext context) {
    final amount = widget.amount;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppUIConstants.spacing2Xl,
          AppUIConstants.spacingXl,
          AppUIConstants.spacing2Xl,
          AppUIConstants.spacingLg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Approve ${widget.name}?', style: AppUIConstants.headingMd),
            const SizedBox(height: 4),
            Text(
              widget.bed == null
                  ? 'Their stay becomes active and they are notified.'
                  : 'Bed ${widget.bed} becomes active and they are notified.',
              style: AppUIConstants.bodyMd,
            ),
            const SizedBox(height: AppUIConstants.spacingMd),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _recordPayment,
              activeThumbColor: AppUIConstants.primaryLight,
              onChanged: (v) => setState(() => _recordPayment = v),
              title: const Text('Record rent as received'),
              subtitle: Text(
                amount == null
                    ? 'Creates a payment record and invoice.'
                    : 'Creates a ₹${amount.toStringAsFixed(0)} payment '
                          'record and invoice.',
                style: AppUIConstants.bodySm,
              ),
            ),
            const SizedBox(height: AppUIConstants.spacingMd),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: AppUIConstants.spacingMd),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _recordPayment),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppUIConstants.primaryLight,
                      foregroundColor: AppUIConstants.background,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value, {this.emphasize = false});

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 92, child: Text(label, style: AppUIConstants.bodySm)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
                color: emphasize
                    ? AppUIConstants.primaryLight
                    : AppUIConstants.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppUIConstants.spacing3Xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppUIConstants.textTertiary),
            const SizedBox(height: AppUIConstants.spacingLg),
            Text(title, style: AppUIConstants.headingSm),
            const SizedBox(height: AppUIConstants.spacingSm),
            Text(
              body,
              textAlign: TextAlign.center,
              style: AppUIConstants.bodyMd,
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: AppUIConstants.spacingLg),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
