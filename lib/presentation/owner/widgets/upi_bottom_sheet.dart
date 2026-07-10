import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../domain/entities/subscription_plan.dart';
import '../../core/app_ui_constants.dart';

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
      'playStoreUrl': 'https://play.google.com/store/apps/details?id=com.google.android.apps.nbu.paisa.user',
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              const SizedBox(height: 20),
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
              Text(
                'Pay with UPI',
                style: AppUIConstants.bodyMd.copyWith(
                  color: AppUIConstants.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '₹${widget.amount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildUpiIdSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        border: Border.all(color: AppUIConstants.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'UPI ID',
                  style: AppUIConstants.bodySm.copyWith(
                    color: AppUIConstants.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  SubscriptionPlan.upiId,
                  style: AppUIConstants.bodyMd.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: SubscriptionPlan.upiId));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('UPI ID copied'),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: AppUIConstants.primary,
                ),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy'),
          ),
        ],
      ),
    );
  }

  Widget _buildUpiAppsGrid(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select UPI App',
          style: AppUIConstants.bodyMd.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _upiApps.map((app) {
            return InkWell(
              onTap: () => _launchUpiApp(context, app),
              borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
              child: Container(
                width: (MediaQuery.of(context).size.width - 84) / 3,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppUIConstants.surface,
                  borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
                  border: Border.all(color: AppUIConstants.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: (app['color'] as Color).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        app['icon'] as IconData,
                        color: app['color'] as Color,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      app['name'] as String,
                      style: AppUIConstants.bodySm.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
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
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        border: Border.all(color: AppUIConstants.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 18,
                color: AppUIConstants.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                'How it works',
                style: AppUIConstants.bodyMd.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStep('1', 'Copy UPI ID above'),
          _buildStep('2', 'Open your UPI app and pay'),
          _buildStep('3', 'Enter transaction ID', isLast: true),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppUIConstants.background,
              borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 14,
                  color: AppUIConstants.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Verification within 1 hour',
                  style: AppUIConstants.bodySm.copyWith(
                    color: AppUIConstants.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(String number, String text, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
      child: Row(
        children: [
          Text(
            '$number.',
            style: AppUIConstants.bodyMd.copyWith(
              fontWeight: FontWeight.bold,
              color: AppUIConstants.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppUIConstants.bodySm.copyWith(
                color: AppUIConstants.textSecondary,
              ),
            ),
          ),
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
        final intentUri = Uri.parse('intent://#Intent;scheme=upi;package=$androidPackage;end');
        if (await canLaunchUrl(intentUri)) {
          await launchUrl(intentUri, mode: LaunchMode.externalApplication);
          widget.onAppLaunched();
          return;
        }
      }
      
      // Try fallback Android package (for GPay)
      if (androidPackageFallback != null) {
        final intentUri = Uri.parse('intent://#Intent;scheme=upi;package=$androidPackageFallback;end');
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
