import 'package:material_ui/material_ui.dart';

import '../../../../core/app_ui_constants.dart';

/// Amount display with rupee figure, tinted by [color].
class SubscriptionAmountBadge extends StatelessWidget {
  const SubscriptionAmountBadge({
    required this.amount,
    this.color = AppUIConstants.textPrimary,
    super.key,
  });

  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      '₹${amount.toStringAsFixed(0)}',
      style: AppUIConstants.headingMd.copyWith(
        color: color,
        letterSpacing: -0.5,
      ),
    );
  }
}
