import 'package:material_ui/material_ui.dart';

import '../../../../domain/usecases/get_student_memberships.dart';
import '../../../core/app_ui_constants.dart';
import '../../cubit/student_home_state.dart';
import '../../home/home_navigator.dart';
import 'quick_actions.dart';

/// Shortcut tiles under the featured membership.
class HomeQuickActionsSection extends StatelessWidget {
  const HomeQuickActionsSection({
    super.key,
    required this.memberships,
    required this.documentStatus,
    required this.navigator,
  });

  final List<StudentMembershipInfo> memberships;
  final DocumentVerificationStatus documentStatus;
  final StudentHomeNavigator navigator;

  @override
  Widget build(BuildContext context) {
    final docColor = switch (documentStatus) {
      DocumentVerificationStatus.verified => AppUIConstants.success,
      DocumentVerificationStatus.pending => AppUIConstants.warning,
      DocumentVerificationStatus.none => null,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          HomeQuickActions(
            actions: [
              HomeQuickAction(
                icon: Icons.receipt_long_outlined,
                label: 'Invoices',
                onTap: () => navigator.invoices(context),
              ),
              HomeQuickAction(
                icon: Icons.folder_open_rounded,
                label: 'Documents',
                statusColor: docColor,
                onTap: () => navigator.documents(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
