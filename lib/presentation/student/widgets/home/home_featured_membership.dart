import 'package:material_ui/material_ui.dart';

import '../../../../domain/usecases/get_student_memberships.dart';
import '../../home/home_navigator.dart';
import '../../home/membership_groups.dart';
import '../unified_membership_card.dart';
import 'membership_switcher.dart';

/// Membership card wired to the home navigator.
class HomeMembershipCard extends StatelessWidget {
  const HomeMembershipCard({
    super.key,
    required this.info,
    required this.userId,
    required this.navigator,
  });

  final StudentMembershipInfo info;
  final String userId;
  final StudentHomeNavigator navigator;

  @override
  Widget build(BuildContext context) {
    return UnifiedMembershipCard(
      info: info,
      userId: userId,
      onCardTap: info.library == null
          ? null
          : () => info.isPendingPayment
                ? navigator.payment(context, info)
                : navigator.libraryDetails(context, info),
    );
  }
}

/// Featured membership with a chip switcher when there are several.
class HomeFeaturedMembership extends StatelessWidget {
  const HomeFeaturedMembership({
    super.key,
    required this.groups,
    required this.userId,
    required this.navigator,
    required this.onSelected,
  });

  final MembershipGroups groups;
  final String userId;
  final StudentHomeNavigator navigator;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final featured = groups.featured!;

    return Column(
      children: [
        if (groups.current.length > 1) ...[
          HomeMembershipSwitcher(
            items: [
              for (final i in groups.current)
                (
                  id: i.membership.id,
                  label: membershipSwitcherLabel(i, groups.current),
                ),
            ],
            selectedId: featured.membership.id,
            onSelected: onSelected,
          ),
          const SizedBox(height: 12),
        ],
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: KeyedSubtree(
            key: ValueKey(featured.membership.id),
            child: HomeMembershipCard(
              info: featured,
              userId: userId,
              navigator: navigator,
            ),
          ),
        ),
      ],
    );
  }
}
