import 'package:material_ui/material_ui.dart';

import '../../core/app_ui_constants.dart';

/// Brand mark with title and subtitle, shown at the top of each auth step.
class AuthBrandHeader extends StatelessWidget {
  const AuthBrandHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.onLogoTap,
  });

  final String title;
  final String subtitle;

  /// Optional tap handler on the logo (used for the hidden admin entry).
  final VoidCallback? onLogoTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onLogoTap,
          child: Image.asset(
            'assets/images/app_logo.png',
            width: 80,
            height: 80,
          ),
        ),
        const SizedBox(height: AppUIConstants.spacing2Xl),
        Text(
          title,
          style: AppUIConstants.headingLg.copyWith(fontSize: 26),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppUIConstants.spacingSm),
        Text(
          subtitle,
          style: AppUIConstants.bodyMd,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
