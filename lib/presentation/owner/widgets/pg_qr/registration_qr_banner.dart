import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/utils/pg_invite_link.dart';
import '../../../../domain/entities/library.dart';
import '../../../core/app_ui_constants.dart';
import '../../../core/widgets/premium_kit.dart';

/// Dashboard card that opens the PG's registration QR poster.
class RegistrationQrBanner extends StatelessWidget {
  const RegistrationQrBanner({
    super.key,
    required this.library,
    required this.onTap,
    required this.onHide,
  });

  final Library library;
  final VoidCallback onTap;
  final VoidCallback onHide;

  Future<void> _shareLink(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    return Share.share(
      'Request a bed at ${library.name}: ${PgInviteLink.url(library.id)}',
      sharePositionOrigin: box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PremiumCard(
          onTap: onTap,
          padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Fill beds faster',
                      style: AppUIConstants.headingSm,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Residents scan your QR to see room types and request a bed.',
                      style: AppUIConstants.bodySm,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: onTap,
                          icon: const Icon(Icons.qr_code_2_rounded, size: 12),
                          label: const Text('Print QR'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppUIConstants.primaryLight,
                            foregroundColor: AppUIConstants.background,
                            visualDensity: VisualDensity.compact,
                            textStyle: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Builder(
                          builder: (context) => TextButton.icon(
                            onPressed: () => _shareLink(context),
                            icon: const Icon(Icons.share_rounded, size: 12),
                            label: const Text('Share link'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppUIConstants.textSecondary,
                              visualDensity: VisualDensity.compact,
                              textStyle: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: QrImageView(
                  data: PgInviteLink.url(library.id),
                  size: 72,
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: IconButton(
            onPressed: onHide,
            tooltip: 'Hide',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close_rounded, size: 16),
            color: AppUIConstants.textTertiary,
          ),
        ),
      ],
    );
  }
}
