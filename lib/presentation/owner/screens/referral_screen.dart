import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/referral.dart';
import '../../core/app_ui_constants.dart';
import '../cubit/referral_cubit.dart';
import '../widgets/referral_widgets.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({
    super.key,
    required this.ownerId,
    required this.ownerName,
    required this.hasActiveSubscription,
  });

  final String ownerId;
  final String ownerName;
  final bool hasActiveSubscription;

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ReferralCubit>().loadStats(widget.ownerId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUIConstants.background,
      appBar: AppBar(
        title: const Text('Refer & Earn'),
        backgroundColor: AppUIConstants.surface,
        foregroundColor: AppUIConstants.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      body: BlocConsumer<ReferralCubit, ReferralState>(
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
          if (state.isLoading && state.stats == null) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              context.read<ReferralCubit>().loadStats(widget.ownerId);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppUIConstants.spacingLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeroSection(state),
                  const SizedBox(height: 20),
                  if (!widget.hasActiveSubscription)
                    _buildNoSubscriptionNotice()
                  else if (!state.hasReferralCode)
                    _buildGenerateCodeSection(state)
                  else ...[
                    _buildCodeCard(state),
                    const SizedBox(height: 20),
                    _buildStatsRow(state),
                    const SizedBox(height: 20),
                    _buildWalletCard(state),
                    const SizedBox(height: 20),
                    if (state.stats!.withdrawalRequests.isNotEmpty) ...[
                      _buildWithdrawalRequests(state),
                      const SizedBox(height: 20),
                    ],
                    if (state.stats!.unclaimedRewards.isNotEmpty)
                      _buildUnclaimedRewards(state),
                    if (_claimedRewards(state).isNotEmpty) ...[
                      _buildClaimedRewardsSection(state),
                      const SizedBox(height: 20),
                    ],
                    _buildHowItWorks(),
                    const SizedBox(height: 20),
                    if (state.stats!.redemptions.isNotEmpty)
                      _buildRedemptionHistory(state),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroSection(ReferralState state) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppUIConstants.primary,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.card_giftcard_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Refer & Earn Rewards',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Share your code with other library owners.\n'
            'They get 15% off, you earn a free month or ₹149!',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNoSubscriptionNotice() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppUIConstants.cardDecorationFlat,
      child: Column(
        children: [
          Icon(Icons.lock_outline, color: AppUIConstants.warning, size: 40),
          const SizedBox(height: 12),
          Text(
            'Active Subscription Required',
            style: AppUIConstants.headingSm,
          ),
          const SizedBox(height: 8),
          Text(
            'You need an active subscription to create and share '
            'your referral code. Subscribe to unlock this feature.',
            style: AppUIConstants.bodyMd,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateCodeSection(ReferralState state) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppUIConstants.cardDecoration,
      child: Column(
        children: [
          Icon(
            Icons.share_rounded,
            color: AppUIConstants.accent,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'Get Your Referral Code',
            style: AppUIConstants.headingSm,
          ),
          const SizedBox(height: 8),
          Text(
            'Generate a unique code to start earning rewards',
            style: AppUIConstants.bodyMd,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: state.status == ReferralScreenStatus.creating
                  ? null
                  : () => context.read<ReferralCubit>().generateCode(
                        ownerId: widget.ownerId,
                        ownerName: widget.ownerName,
                      ),
              style: AppUIConstants.primaryButtonStyle,
              child: state.status == ReferralScreenStatus.creating
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Generate Code'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeCard(ReferralState state) {
    final code = state.stats!.referral!.code;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppUIConstants.cardDecoration,
      child: Column(
        children: [
          Text('Your Referral Code', style: AppUIConstants.bodySm),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: AppUIConstants.background,
              borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
              border: Border.all(
                color: AppUIConstants.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    code,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppUIConstants.textPrimary,
                      letterSpacing: 2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 20),
                  color: AppUIConstants.secondary,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code copied!')),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _shareCode(code),
              icon: const Icon(Icons.share_rounded, size: 18),
              label: const Text('Share with Friends'),
              style: AppUIConstants.primaryButtonStyle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(ReferralState state) {
    final stats = state.stats!;
    return Row(
      children: [
        Expanded(
          child: ReferralStatTile(
            label: 'Referred',
            value: '${stats.totalReferred}',
            icon: Icons.people_outline_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ReferralStatTile(
            label: 'Converted',
            value: '${stats.totalConverted}',
            icon: Icons.check_circle_outline_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ReferralStatTile(
            label: 'Unclaimed',
            value: '${stats.unclaimedRewards.length}',
            icon: Icons.card_giftcard_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildWalletCard(ReferralState state) {
    final wallet = state.stats?.wallet;
    final balance = wallet?.balance ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppUIConstants.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet_rounded,
                color: AppUIConstants.accent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text('Referral Wallet', style: AppUIConstants.headingSm),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Balance', style: AppUIConstants.bodySm),
                    const SizedBox(height: 4),
                    Text(
                      '₹${balance.toStringAsFixed(0)}',
                      style: AppUIConstants.statValue,
                    ),
                  ],
                ),
              ),
              if (balance > 0)
                OutlinedButton(
                  onPressed: () => _showWithdrawalSheet(balance),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppUIConstants.primary,
                    side: const BorderSide(color: AppUIConstants.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppUIConstants.radiusSm,
                      ),
                    ),
                  ),
                  child: const Text('Withdraw'),
                ),
            ],
          ),
          if (wallet != null && wallet.totalEarned > 0) ...[
            const SizedBox(height: 12),
            const Divider(color: AppUIConstants.divider),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Earned: ₹${wallet.totalEarned.toStringAsFixed(0)}',
                  style: AppUIConstants.bodySm,
                ),
                Text(
                  'Withdrawn: ₹${wallet.totalWithdrawn.toStringAsFixed(0)}',
                  style: AppUIConstants.bodySm,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUnclaimedRewards(ReferralState state) {
    final rewards = state.stats!.unclaimedRewards;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppUIConstants.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'NEW',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppUIConstants.success,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text('Unclaimed Rewards', style: AppUIConstants.headingSm),
          ],
        ),
        const SizedBox(height: 12),
        ...rewards.map((r) => _buildRewardClaimCard(r)),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildRewardClaimCard(ReferralRedemption redemption) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        border: Border.all(
          color: AppUIConstants.success.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A friend subscribed using your code!',
            style: AppUIConstants.bodyLg,
          ),
          const SizedBox(height: 4),
          Text(
            'Choose your reward:',
            style: AppUIConstants.bodySm,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ReferralRewardOptionButton(
                  icon: Icons.calendar_month_rounded,
                  label: 'Free Month',
                  subtitle: 'Extend plan by 1 month',
                  onTap: () => context.read<ReferralCubit>().claimReward(
                        ownerId: widget.ownerId,
                        redemptionId: redemption.id,
                        rewardType: ReferralRewardType.freeMonth,
                      ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ReferralRewardOptionButton(
                  icon: Icons.account_balance_wallet_rounded,
                  label: '₹149 Credit',
                  subtitle: 'Add to wallet',
                  onTap: () => context.read<ReferralCubit>().claimReward(
                        ownerId: widget.ownerId,
                        redemptionId: redemption.id,
                        rewardType: ReferralRewardType.walletCredit,
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<ReferralRedemption> _claimedRewards(ReferralState state) {
    return state.stats?.redemptions
            .where((r) => r.rewardClaimed && r.rewardType != null)
            .toList() ??
        [];
  }

  Widget _buildClaimedRewardsSection(ReferralState state) {
    final claimed = _claimedRewards(state);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppUIConstants.cardDecorationFlat,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.verified_rounded,
                color: AppUIConstants.success,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text('Claimed Rewards', style: AppUIConstants.headingSm),
            ],
          ),
          const SizedBox(height: 12),
          ...claimed.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      r.rewardType == ReferralRewardType.freeMonth
                          ? Icons.calendar_month_rounded
                          : Icons.account_balance_wallet_rounded,
                      size: 16,
                      color: AppUIConstants.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        r.rewardType == ReferralRewardType.freeMonth
                            ? '+1 Month Free (subscription extended)'
                            : '₹149 Credit (added to wallet)',
                        style: AppUIConstants.bodyMd,
                      ),
                    ),
                    if (r.convertedAt != null)
                      Text(
                        _formatDate(r.convertedAt!),
                        style: AppUIConstants.caption,
                      ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildWithdrawalRequests(ReferralState state) {
    final requests = state.stats!.withdrawalRequests;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppUIConstants.cardDecorationFlat,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Withdrawal Requests', style: AppUIConstants.headingSm),
          const SizedBox(height: 12),
          ...requests.take(5).map((w) {
            final Color statusColor;
            final IconData statusIcon;
            final String statusLabel;

            if (w.isApproved) {
              statusColor = AppUIConstants.success;
              statusIcon = Icons.check_circle_rounded;
              statusLabel = 'Approved';
            } else if (w.isRejected) {
              statusColor = AppUIConstants.error;
              statusIcon = Icons.cancel_rounded;
              statusLabel = 'Rejected';
            } else {
              statusColor = AppUIConstants.warning;
              statusIcon = Icons.hourglass_top_rounded;
              statusLabel = 'Pending';
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(statusIcon, size: 18, color: statusColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '₹${w.amount.toStringAsFixed(0)} — $statusLabel',
                          style: AppUIConstants.bodyMd,
                        ),
                        if (w.upiId != null && w.upiId!.isNotEmpty)
                          Text(
                            'UPI: ${w.upiId}',
                            style: AppUIConstants.caption,
                          ),
                        if (w.isRejected && w.rejectionReason != null)
                          Text(
                            'Reason: ${w.rejectionReason}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppUIConstants.error,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (w.createdAt != null)
                    Text(_formatDate(w.createdAt!),
                        style: AppUIConstants.caption),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHowItWorks() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppUIConstants.cardDecorationFlat,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How It Works', style: AppUIConstants.headingSm),
          const SizedBox(height: 16),
          ReferralHowItWorksStep(
            number: '1',
            title: 'Share your code',
            subtitle: 'Send your unique referral code to other library owners',
          ),
          ReferralHowItWorksStep(
            number: '2',
            title: 'They subscribe',
            subtitle: 'They get 15% off their first subscription',
          ),
          ReferralHowItWorksStep(
            number: '3',
            title: 'You earn',
            subtitle: 'Choose: 1 month free or ₹149 wallet credit',
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildRedemptionHistory(ReferralState state) {
    final redemptions = state.stats!.redemptions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Referral History', style: AppUIConstants.headingSm),
        const SizedBox(height: 12),
        ...redemptions.take(10).map((r) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: AppUIConstants.cardDecorationFlat,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: r.isConverted
                          ? AppUIConstants.success.withValues(alpha: 0.1)
                          : AppUIConstants.warning.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      r.isConverted
                          ? Icons.check_circle_rounded
                          : Icons.hourglass_top_rounded,
                      size: 16,
                      color: r.isConverted
                          ? AppUIConstants.success
                          : AppUIConstants.warning,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.isConverted ? 'Converted' : 'Pending',
                          style: AppUIConstants.bodyLg,
                        ),
                        if (r.rewardClaimed && r.rewardType != null)
                          Text(
                            r.rewardType == ReferralRewardType.freeMonth
                                ? 'Reward: Free month'
                                : 'Reward: ₹149 credit',
                            style: AppUIConstants.bodySm,
                          ),
                      ],
                    ),
                  ),
                  if (r.createdAt != null)
                    Text(
                      _formatDate(r.createdAt!),
                      style: AppUIConstants.caption,
                    ),
                ],
              ),
            )),
      ],
    );
  }

  void _shareCode(String code) {
    final box = context.findRenderObject() as RenderBox?;
    final origin =
        box != null ? box.localToGlobal(Offset.zero) & box.size : null;

    Share.share(
      'Use my referral code *$code* on PG Sathi and '
      'get 15% off your first subscription! '
      'Download now and manage your library like a pro.\n\n'
      'Android: ${AppConstants.playStoreUrl}\n'
      'iOS: ${AppConstants.appStoreUrl}',
      sharePositionOrigin: origin,
    );
  }

  void _showWithdrawalSheet(double balance) {
    final upiController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppUIConstants.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Withdraw Funds', style: AppUIConstants.headingMd),
            const SizedBox(height: 8),
            Text(
              'Available: ₹${balance.toStringAsFixed(0)}',
              style: AppUIConstants.bodyMd,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: upiController,
              decoration: InputDecoration(
                labelText: 'Your UPI ID',
                hintText: 'name@upi',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    AppUIConstants.radiusSm,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.read<ReferralCubit>().requestWithdrawal(
                        ownerId: widget.ownerId,
                        amount: balance,
                        upiId: upiController.text.trim().isNotEmpty
                            ? upiController.text.trim()
                            : null,
                      );
                },
                style: AppUIConstants.primaryButtonStyle,
                child: Text('Withdraw ₹${balance.toStringAsFixed(0)}'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }
}
