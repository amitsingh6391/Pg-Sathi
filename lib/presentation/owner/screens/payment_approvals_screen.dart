import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/di/injection_container.dart';
import '../../../domain/entities/library.dart';
import '../../../domain/entities/payment.dart';
import '../../../domain/usecases/get_pending_cash_payments.dart';
import '../../core/app_ui_constants.dart';
import '../cubit/cash_approval_cubit.dart';
import '../cubit/cash_approval_state.dart';

/// Combined payment approvals screen with tabs for UPI and Cash.
class PaymentApprovalsScreen extends StatefulWidget {
  const PaymentApprovalsScreen({
    super.key,
    required this.library,
    this.initialTab = 0,
  });

  final Library library;
  final int initialTab;

  @override
  State<PaymentApprovalsScreen> createState() => _PaymentApprovalsScreenState();
}

class _PaymentApprovalsScreenState extends State<PaymentApprovalsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late CashApprovalCubit _cubit;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _cubit = sl<CashApprovalCubit>()..loadPendingPayments(widget.library.id);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.of(context).pop(_hasChanges);
      },
      child: BlocProvider.value(
        value: _cubit,
        child: Scaffold(
          backgroundColor: AppUIConstants.background,
          appBar: AppBar(
            backgroundColor: AppUIConstants.primary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(_hasChanges),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Approve Payments',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  widget.library.name,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            iconTheme: const IconThemeData(color: Colors.white),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              tabs: const [
                Tab(text: 'UPI Payments'),
                Tab(text: 'Cash Payments'),
              ],
            ),
          ),
          body: BlocConsumer<CashApprovalCubit, CashApprovalState>(
            listener: (context, state) {
              if (state.isApproved) {
                _hasChanges = true;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Payment approved successfully'),
                    backgroundColor: AppUIConstants.success,
                  ),
                );
                _cubit.resetToLoaded();
              } else if (state.isRejected) {
                _hasChanges = true;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Payment rejected'),
                    backgroundColor: AppUIConstants.warning,
                  ),
                );
                _cubit.resetToLoaded();
              } else if (state.isError && state.errorMessage != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.errorMessage!),
                    backgroundColor: AppUIConstants.error,
                  ),
                );
              }
            },
            builder: (context, state) {
              if (state.isLoading) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: AppUIConstants.primary,
                  ),
                );
              }

              // Filter by payment mode
              final upiPayments = state.pendingPayments
                  .where((p) => p.payment.mode == PaymentMode.upi)
                  .toList();
              final cashPayments = state.pendingPayments
                  .where((p) => p.payment.mode == PaymentMode.cash)
                  .toList();

              return TabBarView(
                controller: _tabController,
                children: [
                  _PaymentList(
                    payments: upiPayments,
                    isUpi: true,
                    library: widget.library,
                  ),
                  _PaymentList(
                    payments: cashPayments,
                    isUpi: false,
                    library: widget.library,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PaymentList extends StatelessWidget {
  const _PaymentList({
    required this.payments,
    required this.isUpi,
    required this.library,
  });

  final List<PendingCashPaymentInfo> payments;
  final bool isUpi;
  final Library library;

  @override
  Widget build(BuildContext context) {
    if (payments.isEmpty) {
      return _EmptyState(isUpi: isUpi);
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<CashApprovalCubit>().loadPendingPayments(library.id);
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: payments.length,
        itemBuilder: (context, index) {

          final info = payments[index];
          return _PaymentCard(info: info, isUpi: isUpi, library: library);
        },
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.info,
    required this.isUpi,
    required this.library,
  });

  final PendingCashPaymentInfo info;
  final bool isUpi;
  final Library library;

  @override
  Widget build(BuildContext context) {
    final payment = info.payment;
    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');

    return BlocBuilder<CashApprovalCubit, CashApprovalState>(
      builder: (context, state) {
        final isProcessing = state.isProcessingPayment(payment.id);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppUIConstants.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppUIConstants.border),
            boxShadow: [AppUIConstants.shadowSm],
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color:
                            (isUpi
                                    ? const Color(0xFF6366F1)
                                    : const Color(0xFF059669))
                                .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          info.studentName.isNotEmpty
                              ? info.studentName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isUpi
                                ? const Color(0xFF6366F1)
                                : const Color(0xFF059669),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            info.studentName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppUIConstants.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Seat ${info.seatNumber} • ${info.slot}',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppUIConstants.textSecondary,
                            ),
                          ),
                          Text(
                            payment.createdAt != null
                                ? dateFormat.format(payment.createdAt!)
                                : 'N/A',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppUIConstants.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppUIConstants.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '₹${payment.amount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppUIConstants.success,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Actions
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppUIConstants.background,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isProcessing
                            ? null
                            : () {
                                context.read<CashApprovalCubit>().reject(
                                  paymentId: payment.id,
                                  ownerId: library.ownerId,
                                  libraryId: library.id,
                                );
                              },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppUIConstants.error,
                          side: BorderSide(
                            color: AppUIConstants.error.withValues(alpha: 0.3),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Reject',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isProcessing
                            ? null
                            : () {
                                context.read<CashApprovalCubit>().approve(
                                  paymentId: payment.id,
                                  ownerId: library.ownerId,
                                  libraryId: library.id,
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppUIConstants.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: isProcessing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Approve',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isUpi});

  final bool isUpi;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppUIConstants.divider,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isUpi ? Icons.account_balance_rounded : Icons.payments_rounded,
                size: 40,
                color: AppUIConstants.textTertiary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Pending ${isUpi ? 'UPI' : 'Cash'} Payments',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppUIConstants.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'All ${isUpi ? 'UPI' : 'cash'} payments have been processed.',
              style: TextStyle(
                fontSize: 13,
                color: AppUIConstants.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
