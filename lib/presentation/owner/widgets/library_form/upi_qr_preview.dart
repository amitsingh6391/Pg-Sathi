import 'package:material_ui/material_ui.dart';
import 'package:unicons/unicons.dart';

import '../../../core/app_ui_constants.dart';

/// Preview of the uploaded UPI QR code with replace and remove actions.
class UpiQrPreview extends StatelessWidget {
  const UpiQrPreview({
    super.key,
    required this.imageUrl,
    required this.isBusy,
    required this.onReplace,
    required this.onRemove,
  });

  final String imageUrl;
  final bool isBusy;
  final VoidCallback onReplace;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppUIConstants.surface,
            borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
            border: Border.all(color: AppUIConstants.border),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
                child: SizedBox(
                  width: 88,
                  height: 88,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    // Show via an <img> tag on web if the CORS fetch is blocked.
                    webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const _ImagePlaceholder(showSpinner: true);
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const _ImagePlaceholder();
                    },
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          UniconsLine.check_circle,
                          color: AppUIConstants.success,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text('QR code added', style: AppUIConstants.bodyLg),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Residents can scan this to pay rent directly',
                      style: AppUIConstants.bodySm,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isBusy ? null : onReplace,
                icon: const Icon(UniconsLine.sync, size: 18),
                label: const Text('Replace'),
                style: AppUIConstants.secondaryButtonStyle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isBusy ? null : onRemove,
                icon: const Icon(UniconsLine.trash_alt, size: 18),
                label: const Text('Remove'),
                style: AppUIConstants.secondaryButtonStyle.copyWith(
                  foregroundColor: const WidgetStatePropertyAll(
                    AppUIConstants.error,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({this.showSpinner = false});

  final bool showSpinner;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppUIConstants.skeletonBase,
      child: Center(
        child: showSpinner
            ? const CircularProgressIndicator(strokeWidth: 2)
            : const Icon(
                UniconsLine.image_v,
                color: AppUIConstants.textTertiary,
              ),
      ),
    );
  }
}
