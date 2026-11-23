import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../../../domain/entities/promo_offer.dart';
import '../../core/app_ui_constants.dart';

/// Preview dialog showing how the promo will appear to owners.
class PromoPreviewDialog extends StatelessWidget {
  const PromoPreviewDialog({
    super.key,
    required this.promo,
    this.localImage,
    this.existingImageUrl,
  });

  final PromoOffer promo;
  final File? localImage;
  final String? existingImageUrl;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        decoration: BoxDecoration(
          color: AppUIConstants.surface,
          borderRadius: BorderRadius.circular(AppUIConstants.radiusLg),
          border: Border.all(color: AppUIConstants.border),
          boxShadow: [AppUIConstants.shadowLg],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPreviewBadge(),
            _buildHeader(context),
            Flexible(child: SingleChildScrollView(child: _buildImage())),
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewBadge() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppUIConstants.background,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppUIConstants.radiusLg),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.visibility_outlined,
            size: 16,
            color: AppUIConstants.textSecondary,
          ),
          const SizedBox(width: 6),
          Text(
            'OWNER PREVIEW',
            style: TextStyle(
              color: AppUIConstants.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppUIConstants.spacingLg,
        vertical: AppUIConstants.spacingMd,
      ),
      decoration: const BoxDecoration(color: AppUIConstants.surfaceMuted),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppUIConstants.surface,
              borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
            ),
            child: Icon(
              Icons.local_offer_rounded,
              color: AppUIConstants.primaryLight,
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
              onTap: () => Navigator.pop(context),
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
    if (localImage != null) {
      return ClipRRect(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280, minHeight: 150),
          child: Image.file(
            localImage!,
            width: double.infinity,
            fit: BoxFit.contain,
          ),
        ),
      );
    }

    if (existingImageUrl != null && existingImageUrl!.isNotEmpty) {
      return ClipRRect(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280, minHeight: 150),
          child: Image.network(
            existingImageUrl!,
            width: double.infinity,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                height: 200,
                color: AppUIConstants.background,
                child: const Center(child: CircularProgressIndicator()),
              );
            },
            errorBuilder: (context, error, stack) => _buildDefaultPlaceholder(),
          ),
        ),
      );
    }

    return _buildDefaultPlaceholder();
  }

  Widget _buildDefaultPlaceholder() {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppUIConstants.surface,
        border: Border(bottom: BorderSide(color: AppUIConstants.border)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppUIConstants.primarySoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.local_offer_rounded,
              size: 48,
              color: AppUIConstants.primary,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              promo.title.isNotEmpty ? promo.title : 'Special Offer',
              style: const TextStyle(
                color: AppUIConstants.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Exclusive for You!',
            style: TextStyle(color: AppUIConstants.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppUIConstants.spacingLg),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    foregroundColor: AppUIConstants.textSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppUIConstants.radiusSm,
                      ),
                      side: BorderSide(color: AppUIConstants.border),
                    ),
                  ),
                  child: const Text(
                    'Not now',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(width: AppUIConstants.spacingMd),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppUIConstants.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppUIConstants.radiusSm,
                      ),
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
                      Icon(_getCtaIcon(), size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Close preview',
                style: TextStyle(
                  color: AppUIConstants.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
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
