import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../domain/entities/subscription_plan.dart';
import '../../core/app_ui_constants.dart';
import '../../core/widgets/premium_kit.dart';

class UpiBottomSheet extends StatefulWidget {
  final double amount;
  final VoidCallback onAppLaunched;
  final Function(String) onError;
  final IconData Function(String appName) getUpiAppIcon;
  final Color Function(String appName) getUpiAppColor;

  const UpiBottomSheet({
    super.key,
    required this.amount,
    required this.onAppLaunched,
    required this.onError,
    required this.getUpiAppIcon,
    required this.getUpiAppColor,
  });

  @override
  State<UpiBottomSheet> createState() => _UpiBottomSheetState();
}

class _UpiBottomSheetState extends State<UpiBottomSheet> {
  final List<Map<String, dynamic>> _upiApps = [
    {
      'name': 'PhonePe',
      'iosScheme': 'phonepe://',
      'androidPackage': 'com.phonepe.app',
      'color': const Color(0xFF5F259F),
      'icon': Icons.phone_android,
    },
    {
      'name': 'Google Pay',
      'iosScheme': 'tez://',
      'androidPackage': 'com.google.android.apps.nbu.paisa.user',
      'androidPackageFallback': 'com.google.android.apps.walletnfcrel',
      'playStoreUrl':
          'https://play.google.com/store/apps/details?id=com.google.android.apps.nbu.paisa.user',
      'color': const Color(0xFF4285F4),
      'icon': Icons.payment,
    },
    {
      'name': 'Paytm',
      'iosScheme': 'paytmmp://',
      'androidPackage': 'net.one97.paytm',
      'color': const Color(0xFF00BAF2),
      'icon': Icons.wallet,
    },
  ];

  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppUIConstants.border)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppUIConstants.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildHeader(context),
              const SizedBox(height: 18),
              _buildUpiIdSection(context),
              const SizedBox(height: 20),
              _buildUpiAppsGrid(context),
              const SizedBox(height: 20),
              _buildHowItWorksSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Pay with UPI', style: AppUIConstants.bodyMd),
              const SizedBox(height: 2),
              Text(
                '₹${widget.amount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: AppUIConstants.textPrimary,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          style: IconButton.styleFrom(
            backgroundColor: AppUIConstants.surfaceMuted,
            foregroundColor: AppUIConstants.textSecondary,
          ),
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Future<void> _copyUpiId() async {
    HapticFeedback.mediumImpact();
    await Clipboard.setData(ClipboardData(text: SubscriptionPlan.upiId));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (mounted) setState(() => _copied = false);
  }

  Widget _buildUpiIdSection(BuildContext context) {
    final color = _copied
        ? AppUIConstants.success
        : AppUIConstants.primaryLight;
    return GestureDetector(
      onTap: _copyUpiId,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppUIConstants.surfaceMuted,
          borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
          border: Border.all(color: color.withValues(alpha: 0.6)),
        ),
        child: Row(
          children: [
            Icon(Icons.alternate_email_rounded, size: 20, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('UPI ID', style: AppUIConstants.caption),
                  const SizedBox(height: 2),
                  Text(
                    SubscriptionPlan.upiId,
                    style: AppUIConstants.bodyLg,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
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

  Widget _buildUpiAppsGrid(BuildContext context) {
    final tileWidth = (MediaQuery.of(context).size.width - 40 - 24) / 3;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Open your UPI app', style: AppUIConstants.headingSm),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _upiApps.map((app) {
            return Material(
              color: AppUIConstants.surfaceMuted,
              borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _launchUpiApp(context, app);
                },
                borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
                child: Container(
                  width: tileWidth,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      AppUIConstants.radiusMd,
                    ),
                    border: Border.all(color: AppUIConstants.border),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppUIConstants.surfaceMuted,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          app['icon'] as IconData,
                          color: AppUIConstants.textSecondary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        app['name'] as String,
                        style: AppUIConstants.bodySm.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppUIConstants.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildHowItWorksSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppUIConstants.background,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        border: Border.all(color: AppUIConstants.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 18,
                color: AppUIConstants.primaryLight,
              ),
              SizedBox(width: 8),
              Text('How it works', style: AppUIConstants.headingSm),
            ],
          ),
          const SizedBox(height: 14),
          _buildStep('1', 'Copy UPI ID above'),
          _buildStep('2', 'Open your UPI app and pay'),
          _buildStep('3', 'Enter transaction ID', isLast: true),
          const SizedBox(height: 12),
          const PremiumStatusPill(
            'Verification within 1 hour',
            color: AppUIConstants.warning,
          ),
        ],
      ),
    );
  }

  Widget _buildStep(String number, String text, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: AppUIConstants.primarySoft,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppUIConstants.primaryLight,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: AppUIConstants.bodyMd)),
        ],
      ),
    );
  }

  Future<void> _launchUpiApp(
    BuildContext context,
    Map<String, dynamic> app,
  ) async {
    Navigator.pop(context);

    try {
      final iosScheme = app['iosScheme'] as String?;
      final androidPackage = app['androidPackage'] as String?;
      final androidPackageFallback = app['androidPackageFallback'] as String?;
      final playStoreUrl = app['playStoreUrl'] as String?;

      // Try iOS URL scheme
      if (iosScheme != null) {
        final uri = Uri.parse(iosScheme);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          widget.onAppLaunched();
          return;
        }
      }

      // Try primary Android package
      if (androidPackage != null) {
        final intentUri = Uri.parse(
          'intent://#Intent;scheme=upi;package=$androidPackage;end',
        );
        if (await canLaunchUrl(intentUri)) {
          await launchUrl(intentUri, mode: LaunchMode.externalApplication);
          widget.onAppLaunched();
          return;
        }
      }

      // Try fallback Android package (for GPay)
      if (androidPackageFallback != null) {
        final intentUri = Uri.parse(
          'intent://#Intent;scheme=upi;package=$androidPackageFallback;end',
        );
        if (await canLaunchUrl(intentUri)) {
          await launchUrl(intentUri, mode: LaunchMode.externalApplication);
          widget.onAppLaunched();
          return;
        }
      }

      // Try Play Store as final fallback
      if (playStoreUrl != null) {
        final playStoreUri = Uri.parse(playStoreUrl);
        if (await canLaunchUrl(playStoreUri)) {
          await launchUrl(playStoreUri, mode: LaunchMode.externalApplication);
          return;
        }
      }

      // If nothing worked, show error
      widget.onError(
        '${app['name']} not available. Please install it from Play Store.',
      );
    } catch (e) {
      widget.onError('Failed to open ${app['name']}');
    }
  }
}
