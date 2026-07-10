import 'package:flutter/material.dart';

import '../../../domain/entities/user.dart';
import '../../core/app_ui_constants.dart';

/// Owner dashboard header widget.
class OwnerHeader extends StatelessWidget {
  const OwnerHeader({
    super.key,
    required this.libraryName,
    required this.user,
    required this.onRefresh,
    required this.onProfile,
    required this.onSignOut,
  });

  final String? libraryName;
  final User? user;
  final VoidCallback onRefresh;
  final VoidCallback onProfile;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 75,
      floating: false,
      pinned: true,
      automaticallyImplyLeading: false,
      backgroundColor: AppUIConstants.primary,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          color: AppUIConstants.primary,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 35, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    libraryName ?? 'Dashboard',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      height: 1.0,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
            color: Colors.white,
            size: 20,
          ),
          onPressed: onRefresh,
          tooltip: 'Refresh',
        ),
        _MenuButton(onSignOut: onSignOut),
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
        backgroundColor: Colors.white.withValues(alpha: 0.2),
        backgroundImage: user?.avatarUrl != null
            ? NetworkImage(user!.avatarUrl!)
            : null,
        child: user?.avatarUrl == null
            ? Text(
                user?.initials ?? 'O',
                style: const TextStyle(
                  color: Colors.white,
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
  const _MenuButton({required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
      color: AppUIConstants.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
      ),
      onSelected: (value) {
        if (value == 'signout') onSignOut();
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'signout',
          child: Row(
            children: [
              Icon(Icons.logout_rounded, size: 18, color: AppUIConstants.error),
              const SizedBox(width: 12),
              const Text('Sign Out'),
            ],
          ),
        ),
      ],
    );
  }
}
