import 'package:flutter/material.dart';

import '../../../core/utils/whatsapp_launcher.dart';
import '../../../domain/usecases/get_owner_subscription.dart';
import '../../core/app_ui_constants.dart';

/// Clean banner widget for showing pending verification status.
/// With freemium model, this only shows for pending payment states.
class SubscriptionRequiredBanner extends StatelessWidget {
  const SubscriptionRequiredBanner({
    super.key,
    required this.subscriptionStatus,
    required this.onSubscribe,
  });

  final OwnerSubscriptionStatus? subscriptionStatus;
  final VoidCallback onSubscribe;

  static const String _supportPhone = '919548582776';

  @override
  Widget build(BuildContext context) {
    if (subscriptionStatus == null) return const SizedBox.shrink();

    final accessStatus = subscriptionStatus!.accessStatus;
    final hasPendingUpgrade = subscriptionStatus!.hasPendingUpgrade;

    // Only show banner for pending verification or pending upgrade
    final isPendingVerification =
        accessStatus == OwnerAccessStatus.pendingVerification;

    // Special case: Active subscription with pending upgrade
    if (hasPendingUpgrade &&
        accessStatus == OwnerAccessStatus.subscriptionActive) {
      return _buildBanner(
        icon: Icons.upgrade_rounded,
        title: 'Plan Upgrade Pending',
        subtitle: 'Your ${subscriptionStatus!.pendingUpgrade!.durationInMonths}-month upgrade is being verified',
        amount: subscriptionStatus!.pendingUpgrade!.finalAmount,
      );
    }

    // Only show for pending verification
    if (!isPendingVerification) return const SizedBox.shrink();

    final isUpgradeOrRenewal = subscriptionStatus!.isUpgradeOrRenewal;

    return _buildBanner(
      icon: Icons.hourglass_top_rounded,
      title: isUpgradeOrRenewal ? 'Upgrade Pending' : 'Payment Pending',
      subtitle: 'We\'re verifying your payment. Usually takes < 1 hour.',
    );
  }

  Widget _buildBanner({
    required IconData icon,
    required String title,
    required String subtitle,
    double? amount,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppUIConstants.spacingLg),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppUIConstants.primary.withValues(alpha: 0.08),
            AppUIConstants.primary.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppUIConstants.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppUIConstants.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppUIConstants.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppUIConstants.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (amount != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppUIConstants.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '₹${amount.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppUIConstants.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _WhatsAppHelpButton(
                  onTap: () => _launchWhatsApp(),
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: onSubscribe,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                child: Text(
                  'View Status',
                  style: TextStyle(
                    color: AppUIConstants.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _launchWhatsApp() async {
    const message = 'Hi, I have submitted my subscription payment and it\'s pending verification. Please help.';
    await WhatsAppLauncher.launch(phone: _supportPhone, message: message);
  }
}

/// Clean WhatsApp help button for inline use.
class _WhatsAppHelpButton extends StatelessWidget {
  const _WhatsAppHelpButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppUIConstants.primary.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.support_agent_rounded,
                size: 18,
                color: AppUIConstants.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Need Help?',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppUIConstants.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
