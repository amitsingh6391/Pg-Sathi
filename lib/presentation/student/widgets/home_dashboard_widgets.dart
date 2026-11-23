import 'package:material_ui/material_ui.dart';
import 'package:unicons/unicons.dart';

import '../../../domain/entities/user.dart';
import '../../core/app_ui_constants.dart';
import '../../core/widgets/premium_kit.dart';

// =============================================================================
// Hero header: greeting + key figure
// =============================================================================

/// Hero band with avatar, time-aware greeting, refresh / sign-out actions and
/// an optional key-figure panel ([figure]) underneath.
class StudentDashboardHeader extends StatelessWidget {
  const StudentDashboardHeader({
    super.key,
    required this.user,
    required this.onRefresh,
    required this.onSignOut,
    this.onProfile,
    this.figure,
  });

  final User? user;
  final VoidCallback onRefresh;
  final VoidCallback? onProfile;
  final VoidCallback onSignOut;

  /// Key-figure panel shown under the greeting (see [HomeHeroFigure]).
  final Widget? figure;

  static String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final displayName = user?.displayName ?? 'Resident';
    final avatarUrl = user?.avatarUrl;

    return PremiumHero(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(
                avatarUrl: avatarUrl,
                initials: user?.initials ?? 'U',
                onTap: onProfile,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greeting(),
                      style: const TextStyle(
                        color: AppUIConstants.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      displayName,
                      style: const TextStyle(
                        color: AppUIConstants.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              _HeroIconButton(
                icon: UniconsLine.refresh,
                tooltip: 'Refresh',
                onTap: onRefresh,
              ),
              const SizedBox(width: 4),
              _HeroIconButton(
                icon: UniconsLine.signout,
                tooltip: 'Sign out',
                onTap: onSignOut,
              ),
            ],
          ),
          if (figure != null) ...[
            const SizedBox(height: 20),
            Padding(padding: const EdgeInsets.only(right: 8), child: figure!),
          ],
        ],
      ),
    );
  }
}

class _HeroIconButton extends StatelessWidget {
  const _HeroIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppUIConstants.surfaceMuted,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Icon(icon, color: AppUIConstants.textSecondary, size: 19),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.avatarUrl, required this.initials, this.onTap});
  final String? avatarUrl;
  final String initials;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [AppUIConstants.primaryLight, AppUIConstants.primaryLight],
          ),
        ),
        child: ClipOval(
          child: avatarUrl != null && avatarUrl!.isNotEmpty
              ? Image.network(
                  avatarUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _fallback(),
                )
              : _fallback(),
        ),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      color: AppUIConstants.background,
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Fades and slides its child in; [index] staggers siblings.
class HomeReveal extends StatelessWidget {
  const HomeReveal({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + index * 90),
      curve: Curves.easeOutCubic,
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 18), child: c),
      ),
      child: child,
    );
  }
}

// =============================================================================
// Section Header
// =============================================================================

/// Section header with optional trailing widget and "View all" action.
class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.onViewAll,
  });

  final String title;
  final Widget? trailing;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: AppUIConstants.primaryLight,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(title, style: AppUIConstants.headingSm),
        const Spacer(),
        if (trailing != null) trailing!,
        if (onViewAll != null)
          GestureDetector(
            onTap: onViewAll,
            child: const Text(
              'View all',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppUIConstants.primaryLight,
              ),
            ),
          ),
      ],
    );
  }
}
