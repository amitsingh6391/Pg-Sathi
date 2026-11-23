import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/utils/pg_invite_link.dart';
import '../../../../domain/entities/library.dart';
import '../../../core/app_ui_constants.dart';
import 'brand_mark.dart';

/// Printable registration poster. Deliberately light and high-contrast so it
/// scans reliably and prints well; this is the widget that gets exported.
class PgQrPoster extends StatelessWidget {
  const PgQrPoster({super.key, required this.library, this.width = 340});

  final Library library;
  final double width;

  static const Color _ink = Color(0xFF0B0F14);
  static const Color _muted = Color(0xFF5B6673);

  @override
  Widget build(BuildContext context) {
    final area = library.area ?? library.fullAddress;
    final phone = library.ownerPhone;

    return Container(
      width: width,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PgBrandMark(onLight: true),
          const SizedBox(height: 28),
          Text(
            library.name,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _ink,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              height: 1.12,
            ),
          ),
          if (area != null && area.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              area,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _muted, fontSize: 13, height: 1.3),
            ),
          ],
          const SizedBox(height: 24),
          Center(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFD5DBE1), width: 1.5),
              ),
              child: QrImageView(
                data: PgInviteLink.url(library.id),
                size: 220,
                padding: EdgeInsets.zero,
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: _ink,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: _ink,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Center(
            child: Text(
              'Scan to request a bed',
              style: TextStyle(
                color: AppUIConstants.primary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 2),
          const Center(
            child: Text(
              'View room types, pick a bed, send your request',
              style: TextStyle(color: _muted, fontSize: 12),
            ),
          ),
          if (phone != null && phone.isNotEmpty) ...[
            const SizedBox(height: 14),
            Center(
              child: Text(
                'Call $phone',
                style: const TextStyle(
                  color: _ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
          const SizedBox(height: 22),
          const Divider(height: 1, color: Color(0xFFE5E9ED)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Powered by PG Sathi',
                style: TextStyle(color: _muted, fontSize: 12),
              ),
              Text(
                PgInviteLink.host,
                style: const TextStyle(
                  color: AppUIConstants.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
