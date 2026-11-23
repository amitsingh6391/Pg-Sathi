import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/referral.dart';
import '../../core/app_ui_constants.dart';
import '../../core/widgets/premium_kit.dart';
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
        backgroundColor: AppUIConstants.background,
        foregroundColor: AppUIConstants.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
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
            return const Padding(
              padding: EdgeInsets.all(AppUIConstants.spacingLg),
              child: Column(
                children: [
                  ReferralSkeletonBox(height: 170),
                  SizedBox(height: 16),
                  ReferralSkeletonBox(height: 120),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: ReferralSkeletonBox(height: 100)),
                      SizedBox(width: 12),
                      Expanded(child: ReferralSkeletonBox(height: 100)),
                      SizedBox(width: 12),
                      Expanded(child: ReferralSkeletonBox(height: 100)),
                    ],
                  ),
                ],
              ),
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
                  if (!widget.hasActiveSubscription) ...[
                    _buildHeroSection(state),
                    const SizedBox(height: 20),
                    _buildNoSubscriptionNotice(),
                  ] else if (!state.hasReferralCode) ...[
                    _buildHeroSection(state),
                    const SizedBox(height: 20),
                    _buildGenerateCodeSection(state),
                  ] else ...[
                    _buildCodeCard(state),
                    const SizedBox(height: 16),
                    _buildStatsRow(state),
                    const SizedBox(height: 16),
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
    return PremiumCard(
      glow: AppUIConstants.primaryLight,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppUIConstants.surfaceMuted,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppUIConstants.primaryLight.withValues(alpha: 0.5),
              ),
            ),
            child: const Icon(
              Icons.card_giftcard_rounded,
              color: AppUIConstants.primaryLight,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          const Text('Refer & Earn Rewards', style: AppUIConstants.headingMd),
          const SizedBox(height: 8),
          const Text(
            'Share your code with other PG owners.\n'
            'They get 15% off, you earn a free month or ₹149!',
            style: AppUIConstants.bodyMd,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNoSubscriptionNotice() {
    return PremiumCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppUIConstants.warning.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              color: AppUIConstants.warning,
              size: 30,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Active Subscription Required',
            style: AppUIConstants.headingSm,
          ),
          const SizedBox(height: 8),
          const Text(
            'You need an active subscription to create and share '
            'your referral code. Subscribe to unlock this feature.',
            style: AppUIConstants.bodyMd,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const PremiumStatusPill('Locked', color: AppUIConstants.warning),
        ],
      ),
    );
  }

  Widget _buildGenerateCodeSection(ReferralState state) {
    final creating = state.status == ReferralScreenStatus.creating;
    return PremiumCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text('Get Your Referral Code', style: AppUIConstants.headingSm),
          const SizedBox(height: 8),
          const Text(
            'Generate a unique code to start earning rewards',
            style: AppUIConstants.bodyMd,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: creating
                  ? null
                  : () {
                      HapticFeedback.mediumImpact();
                      context.read<ReferralCubit>().generateCode(
                        ownerId: widget.ownerId,
                        ownerName: widget.ownerName,
                      );
                    },
              style: AppUIConstants.primaryButtonStyle,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: creating
                    ? const SizedBox(
                        key: ValueKey('busy'),
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Generate Code', key: ValueKey('idle')),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeCard(ReferralState state) {
    final stats = state.stats!;
    final code = stats.referral!.code;
    final referred = stats.totalReferred;
    final converted = stats.totalConverted;
    final progress = referred == 0
        ? 0.0
        : (converted / referred).clamp(0.0, 1.0);
    return PremiumCard(
      glow: AppUIConstants.primaryLight,
      padding: const EdgeInsets.all(20),
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
                  Icons.card_giftcard_rounded,
                  color: AppUIConstants.primaryLight,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Refer & Earn', style: AppUIConstants.headingSm),
                    Text(
                      'Friends get 15% off, you get a free month or ₹149',
                      style: AppUIConstants.bodySm,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _CodeChip(code: code),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  referred == 0
                      ? 'Invite your first PG owner'
                      : '$converted of $referred invited owners subscribed',
                  style: AppUIConstants.bodySm,
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(
                  color: AppUIConstants.primaryLight,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: v,
                minHeight: 8,
                backgroundColor: AppUIConstants.surfaceMuted,
                valueColor: const AlwaysStoppedAnimation(
                  AppUIConstants.primaryLight,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.selectionClick();
                _shareCode(code);
              },
              icon: const Icon(Icons.share_rounded, size: 18),
              label: const Text('Share with other PG owners'),
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

    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.account_balance_wallet_rounded,
                color: AppUIConstants.primaryLight,
                size: 18,
              ),
              SizedBox(width: 8),
              Text('Referral Wallet', style: AppUIConstants.headingSm),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: balance.toDouble()),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, _) => Text(
                    '₹${v.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: AppUIConstants.textPrimary,
                      letterSpacing: -1,
                    ),
                  ),
                ),
              ),
              if (balance > 0)
                ElevatedButton(
                  onPressed: () => _showWithdrawalSheet(balance),
                  style: AppUIConstants.primaryButtonStyle,
                  child: const Text('Withdraw'),
                ),
            ],
          ),
          if (wallet != null && wallet.totalEarned > 0) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _walletMeta(
                    'Total earned',
                    '₹${wallet.totalEarned.toStringAsFixed(0)}',
                  ),
                ),
                Container(width: 1, height: 28, color: AppUIConstants.divider),
                Expanded(
                  child: _walletMeta(
                    'Withdrawn',
                    '₹${wallet.totalWithdrawn.toStringAsFixed(0)}',
                  ),
                ),
              ],
            ),
          ] else if (balance <= 0) ...[
            const SizedBox(height: 8),
            const Text(
              'Credits you earn from referrals will show up here.',
              style: AppUIConstants.bodySm,
            ),
          ],
        ],
      ),
    );
  }

  Widget _walletMeta(String label, String value) {
    return Column(
      children: [
        Text(value, style: AppUIConstants.headingSm),
        const SizedBox(height: 2),
        Text(label, style: AppUIConstants.caption),
      ],
    );
  }

  Widget _buildUnclaimedRewards(ReferralState state) {
    final rewards = state.stats!.unclaimedRewards;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: PremiumSectionHeader('Unclaimed Rewards')),
            const PremiumStatusPill('NEW', color: AppUIConstants.success),
          ],
        ),
        ...rewards.map((r) => _buildRewardClaimCard(r)),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildRewardClaimCard(ReferralRedemption redemption) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumCard(
        glow: AppUIConstants.success,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A friend subscribed using your code!',
              style: AppUIConstants.bodyLg,
            ),
            const SizedBox(height: 4),
            const Text('Choose your reward:', style: AppUIConstants.bodySm),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PremiumSectionHeader('Claimed Rewards'),
        PremiumCard(
          child: Column(
            children: [
              for (var i = 0; i < claimed.length; i++)
                ReferralTimelineTile(
                  isLast: i == claimed.length - 1,
                  icon: claimed[i].rewardType == ReferralRewardType.freeMonth
                      ? Icons.calendar_month_rounded
                      : Icons.account_balance_wallet_rounded,
                  color: AppUIConstants.success,
                  title: claimed[i].rewardType == ReferralRewardType.freeMonth
                      ? '+1 Month Free (subscription extended)'
                      : '₹149 Credit (added to wallet)',
                  trailing: claimed[i].convertedAt != null
                      ? _formatDate(claimed[i].convertedAt!)
                      : null,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWithdrawalRequests(ReferralState state) {
    final requests = state.stats!.withdrawalRequests.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PremiumSectionHeader('Withdrawal Requests'),
        PremiumCard(
          child: Column(
            children: [
              for (var i = 0; i < requests.length; i++)
                _withdrawalTile(requests[i], i == requests.length - 1),
            ],
          ),
        ),
      ],
    );
  }

  Widget _withdrawalTile(dynamic w, bool isLast) {
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

    final details = <String>[
      if (w.upiId != null && (w.upiId as String).isNotEmpty) 'UPI: ${w.upiId}',
      if (w.isRejected && w.rejectionReason != null)
        'Reason: ${w.rejectionReason}',
    ];

    return ReferralTimelineTile(
      isLast: isLast,
      icon: statusIcon,
      color: statusColor,
      title: '₹${(w.amount as num).toStringAsFixed(0)} — $statusLabel',
      subtitle: details.isEmpty ? null : details.join('\n'),
      trailing: w.createdAt != null
          ? _formatDate(w.createdAt as DateTime)
          : null,
    );
  }

  Widget _buildHowItWorks() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PremiumSectionHeader('How It Works'),
        const PremiumCard(
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              ReferralHowItWorksStep(
                number: '1',
                title: 'Share your code',
                subtitle: 'Send your unique referral code to other PG owners',
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
        ),
      ],
    );
  }

  Widget _buildRedemptionHistory(ReferralState state) {
    final redemptions = state.stats!.redemptions.take(10).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PremiumSectionHeader('Referral History'),
        PremiumCard(
          child: Column(
            children: [
              for (var i = 0; i < redemptions.length; i++)
                ReferralTimelineTile(
                  isLast: i == redemptions.length - 1,
                  icon: redemptions[i].isConverted
                      ? Icons.check_circle_rounded
                      : Icons.hourglass_top_rounded,
                  color: redemptions[i].isConverted
                      ? AppUIConstants.success
                      : AppUIConstants.warning,
                  title: redemptions[i].isConverted ? 'Converted' : 'Pending',
                  subtitle:
                      redemptions[i].rewardClaimed &&
                          redemptions[i].rewardType != null
                      ? (redemptions[i].rewardType ==
                                ReferralRewardType.freeMonth
                            ? 'Reward: Free month'
                            : 'Reward: ₹149 credit')
                      : null,
                  trailing: redemptions[i].createdAt != null
                      ? _formatDate(redemptions[i].createdAt!)
                      : null,
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _shareCode(String code) {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : null;

    Share.share(
      'Use my referral code *$code* on PG Sathi and '
      'get 15% off your first subscription! '
      'Download now and manage your PG like a pro.\n\n'
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
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 4,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Withdraw Funds', style: AppUIConstants.headingMd),
            const SizedBox(height: 4),
            Text(
              '₹${balance.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: AppUIConstants.primaryLight,
              ),
            ),
            const Text('available to withdraw', style: AppUIConstants.bodySm),
            const SizedBox(height: 20),
            TextField(
              controller: upiController,
              style: AppUIConstants.bodyLg,
              decoration: InputDecoration(
                labelText: 'Your UPI ID',
                hintText: 'name@upi',
                prefixIcon: const Icon(Icons.alternate_email_rounded),
                filled: true,
                fillColor: AppUIConstants.surfaceMuted,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
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
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }
}

/// Code display with copy micro-interaction (icon swaps to a check).
class _CodeChip extends StatefulWidget {
  const _CodeChip({required this.code});

  final String code;

  @override
  State<_CodeChip> createState() => _CodeChipState();
}

class _CodeChipState extends State<_CodeChip> {
  bool _copied = false;

  Future<void> _copy() async {
    HapticFeedback.mediumImpact();
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final color = _copied
        ? AppUIConstants.success
        : AppUIConstants.primaryLight;
    return GestureDetector(
      onTap: _copy,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: AppUIConstants.background,
          borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
          border: Border.all(color: color.withValues(alpha: 0.6)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.code,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppUIConstants.textPrimary,
                  letterSpacing: 4,
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Row(
                key: ValueKey(_copied),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _copied ? Icons.check_circle_rounded : Icons.copy_rounded,
                    size: 18,
                    color: color,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _copied ? 'Copied' : 'Copy',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
