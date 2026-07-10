import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../domain/entities/promo_offer.dart';
import '../../core/app_ui_constants.dart';

/// Default placeholder for promos without an image.
Widget _buildDefaultPromoPlaceholder(String title) {
  return Container(
    height: 280,
    width: double.infinity,
    color: AppUIConstants.primary,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.local_offer_rounded,
            size: 56,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            title.isNotEmpty ? title : 'Special Offer',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Exclusive for You!',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 14,
          ),
        ),
      ],
    ),
  );
}

/// Full-screen promotional popup that owners must dismiss to continue.
/// Displays a promotional image with a CTA button.
class PromoPopupDialog extends StatelessWidget {
  const PromoPopupDialog({
    super.key,
    required this.promo,
    required this.onDismiss,
    required this.onCta,
  });

  final PromoOffer promo;
  final VoidCallback onDismiss;
  final VoidCallback onCta;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: AppUIConstants.surface,
          borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
          boxShadow: [AppUIConstants.shadowLg],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            _buildImage(),
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppUIConstants.spacingLg,
        vertical: AppUIConstants.spacingMd,
      ),
      decoration: BoxDecoration(
        color: AppUIConstants.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppUIConstants.radiusLg),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppUIConstants.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
            ),
            child: Icon(
              Icons.local_offer_rounded,
              color: AppUIConstants.accent,
              size: 20,
            ),
          ),
          const SizedBox(width: AppUIConstants.spacingMd),
          Expanded(
            child: Text(
              promo.title.isNotEmpty ? promo.title : 'Special Offer',
              style: AppUIConstants.headingMd.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onDismiss,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close_rounded,
                  color: AppUIConstants.textSecondary,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    // Show default placeholder if no image URL
    if (promo.imageUrl.isEmpty) {
      return _buildDefaultPromoPlaceholder(promo.title);
    }

    return ClipRRect(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxHeight: 400,
          minHeight: 200,
        ),
        child: Image.network(
          promo.imageUrl,
          width: double.infinity,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              height: 300,
              color: AppUIConstants.background,
              child: Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                  strokeWidth: 2,
                  color: AppUIConstants.primary,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            // Fall back to default placeholder on error
            return _buildDefaultPromoPlaceholder(promo.title);
          },
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppUIConstants.spacingLg),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: onDismiss,
              style: TextButton.styleFrom(
                foregroundColor: AppUIConstants.textSecondary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
                  side: BorderSide(color: AppUIConstants.border),
                ),
              ),
              child: const Text(
                'Not Now',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ),
          const SizedBox(width: AppUIConstants.spacingMd),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: onCta,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppUIConstants.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    promo.ctaText,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _getCtaIcon(),
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCtaIcon() {
    switch (promo.ctaAction) {
      case PromoCtaAction.whatsapp:
        return Icons.chat_bubble_outline_rounded;
      case PromoCtaAction.link:
        return Icons.open_in_new_rounded;
      case PromoCtaAction.screen:
        return Icons.arrow_forward_rounded;
      case PromoCtaAction.dismiss:
        return Icons.check_rounded;
    }
  }
}

/// Helper class to handle promo CTA actions
class PromoActionHandler {
  const PromoActionHandler._();

  /// Execute the promo CTA action
  static Future<void> handleCtaAction(PromoOffer promo) async {
    switch (promo.ctaAction) {
      case PromoCtaAction.whatsapp:
        await _openWhatsApp(promo.ctaValue);
        break;
      case PromoCtaAction.link:
        await _openUrl(promo.ctaValue);
        break;
      case PromoCtaAction.screen:
        // Screen navigation should be handled by the caller
        break;
      case PromoCtaAction.dismiss:
        // Nothing to do
        break;
    }
  }

  static Future<void> _openWhatsApp(String? phoneOrMessage) async {
    if (phoneOrMessage == null || phoneOrMessage.isEmpty) return;

    // Check if it's a phone number or a pre-filled message
    String url;
    if (phoneOrMessage.startsWith('+') ||
        phoneOrMessage.startsWith('91') ||
        int.tryParse(phoneOrMessage.replaceAll(RegExp(r'[^\d]'), '')) != null) {
      // It's a phone number
      final phone = phoneOrMessage.replaceAll(RegExp(r'[^\d+]'), '');
      url = 'https://wa.me/$phone?text=Hi, I am interested in the offer!';
    } else {
      // It might be a full WhatsApp URL or message
      url = phoneOrMessage;
    }

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static Future<void> _openUrl(String? url) async {
    if (url == null || url.isEmpty) return;

    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

/// Show promo popup dialog
Future<void> showPromoPopup({
  required BuildContext context,
  required PromoOffer promo,
  required VoidCallback onDismiss,
  required VoidCallback onCtaClicked,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.7),
    builder: (dialogContext) => PromoPopupDialog(
      promo: promo,
      onDismiss: () {
        Navigator.of(dialogContext).pop();
        onDismiss();
      },
      onCta: () async {
        Navigator.of(dialogContext).pop();
        onCtaClicked();
        await PromoActionHandler.handleCtaAction(promo);
      },
    ),
  );
}
