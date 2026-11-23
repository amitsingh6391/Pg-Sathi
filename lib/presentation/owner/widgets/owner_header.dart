import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../../../domain/entities/user.dart';
import '../../core/app_ui_constants.dart';

/// Owner dashboard header: white app bar with the PG name, profile,
/// refresh and overflow menu (same design as Library Manager).
class OwnerHeader extends StatelessWidget {
  const OwnerHeader({
    super.key,
    required this.libraryName,
    required this.user,
    required this.onRefresh,
    required this.onProfile,
    required this.onSignOut,
    this.onPgDetails,
    this.onAddBranch,
    this.hasMultipleBranches = false,
    this.onSwitchBranch,
  });

  final String? libraryName;
  final User? user;
  final VoidCallback onRefresh;
  final VoidCallback onProfile;
  final VoidCallback onSignOut;

  /// When set, the menu gets an 'Edit PG' entry.
  final VoidCallback? onPgDetails;

  /// When set, the menu gets an 'Add Branch' entry (hidden for managers).
  final VoidCallback? onAddBranch;

  /// Shows a dropdown arrow next to the PG name and makes it tappable.
  final bool hasMultipleBranches;
  final VoidCallback? onSwitchBranch;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 75,
      floating: false,
      pinned: true,
      automaticallyImplyLeading: false,
      backgroundColor: AppUIConstants.surface,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      shape: const Border(bottom: BorderSide(color: AppUIConstants.border)),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          color: AppUIConstants.surface,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 35, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: hasMultipleBranches ? onSwitchBranch : null,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              libraryName ?? 'Dashboard',
                              style: const TextStyle(
                                color: AppUIConstants.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                height: 1.0,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (hasMultipleBranches) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: AppUIConstants.textSecondary,
                              size: 20,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        _ProfileButton(user: user, onTap: onProfile),
        IconButton(
          icon: const Icon(
            Icons.refresh_rounded,
            color: AppUIConstants.textSecondary,
            size: 20,
          ),
          onPressed: onRefresh,
          tooltip: 'Refresh',
        ),
        _MenuButton(
          onSignOut: onSignOut,
          onPgDetails: onPgDetails,
          onAddBranch: onAddBranch,
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

class _ProfileButton extends StatelessWidget {
  const _ProfileButton({required this.user, required this.onTap});

  final User? user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: CircleAvatar(
        radius: 14,
        backgroundColor: AppUIConstants.primarySoft,
        backgroundImage: user?.avatarUrl != null
            ? NetworkImage(user!.avatarUrl!)
            : null,
        child: user?.avatarUrl == null
            ? Text(
                user?.initials ?? 'O',
                style: const TextStyle(
                  color: AppUIConstants.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
      ),
      onPressed: onTap,
      tooltip: 'Profile',
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.onSignOut,
    this.onPgDetails,
    this.onAddBranch,
  });

  final VoidCallback onSignOut;
  final VoidCallback? onPgDetails;
  final VoidCallback? onAddBranch;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(
        Icons.more_vert,
        color: AppUIConstants.textSecondary,
        size: 20,
      ),
      color: AppUIConstants.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
      ),
      onSelected: (value) {
        if (value == 'add_branch') onAddBranch?.call();
        if (value == 'pg_details') onPgDetails?.call();
        if (value == 'signout') onSignOut();
      },
      itemBuilder: (context) => [
        if (onAddBranch != null)
          const PopupMenuItem(
            value: 'add_branch',
            child: Row(
              children: [
                Icon(
                  Icons.add_business_rounded,
                  size: 18,
                  color: AppUIConstants.primary,
                ),
                SizedBox(width: 12),
                Text('Add Branch'),
              ],
            ),
          ),
        if (onPgDetails != null)
          const PopupMenuItem(
            value: 'pg_details',
            child: Row(
              children: [
                Icon(
                  Icons.settings_rounded,
                  size: 18,
                  color: AppUIConstants.textSecondary,
                ),
                SizedBox(width: 12),
                Text('Edit PG'),
              ],
            ),
          ),
        const PopupMenuItem(
          value: 'signout',
          child: Row(
            children: [
              Icon(Icons.logout_rounded, size: 18, color: AppUIConstants.error),
              SizedBox(width: 12),
              Text('Sign Out'),
            ],
          ),
        ),
      ],
    );
  }
}
