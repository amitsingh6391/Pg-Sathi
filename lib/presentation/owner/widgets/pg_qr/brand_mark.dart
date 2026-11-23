import 'package:material_ui/material_ui.dart';

import '../../../core/app_ui_constants.dart';

/// PG Sathi mark with wordmark. [onLight] is for the printable poster.
class PgBrandMark extends StatelessWidget {
  const PgBrandMark({
    super.key,
    this.onLight = false,
    this.showTagline = false,
  });

  final bool onLight;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    final title = onLight
        ? const Color(0xFF0B0F14)
        : AppUIConstants.textPrimary;
    final sub = onLight
        ? const Color(0xFF5B6673)
        : AppUIConstants.textSecondary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppUIConstants.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.bed_rounded, size: 17, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PG Sathi',
              style: TextStyle(
                color: title,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                height: 1.1,
              ),
            ),
            if (showTagline)
              Text(
                'Smart PG management',
                style: TextStyle(color: sub, fontSize: 11, height: 1.3),
              ),
          ],
        ),
      ],
    );
  }
}
