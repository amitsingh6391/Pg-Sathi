import 'package:material_ui/material_ui.dart';

import '../../../../domain/usecases/get_student_memberships.dart';
import '../../../core/app_ui_constants.dart';
import '../../home/home_navigator.dart';
import 'home_featured_membership.dart';

/// Single row that opens expired memberships in a bottom sheet.
class PastMembershipsRow extends StatelessWidget {
  const PastMembershipsRow({
    super.key,
    required this.past,
    required this.userId,
    required this.navigator,
  });

  final List<StudentMembershipInfo> past;
  final String userId;
  final StudentHomeNavigator navigator;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Material(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        child: InkWell(
          onTap: () => _showSheet(context),
          borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
              border: Border.all(color: AppUIConstants.border),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.history_rounded,
                  color: AppUIConstants.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Past stays (${past.length})',
                    style: AppUIConstants.bodyMd,
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppUIConstants.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppUIConstants.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(20),
          children: [
            Text('Past stays', style: AppUIConstants.headingMd),
            const SizedBox(height: 16),
            for (final info in past)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: HomeMembershipCard(
                  info: info,
                  userId: userId,
                  navigator: navigator,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
