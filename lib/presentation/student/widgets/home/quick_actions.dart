import 'package:material_ui/material_ui.dart';

import '../../../core/app_ui_constants.dart';

/// One shortcut tile for [HomeQuickActions].
class HomeQuickAction {
  const HomeQuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.statusColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  /// Small dot on the icon (e.g. document verification state).
  final Color? statusColor;
}

/// Row of equal-width shortcut tiles. A null [HomeQuickAction.onTap] dims the tile.
class HomeQuickActions extends StatelessWidget {
  const HomeQuickActions({super.key, required this.actions});

  final List<HomeQuickAction> actions;

  /// With more tiles than fit comfortably, the row scrolls sideways.
  static const _maxFixedTiles = 5;
  static const _scrollTileWidth = 76.0;

  @override
  Widget build(BuildContext context) {
    if (actions.length > _maxFixedTiles) {
      return SizedBox(
        height: 96,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final a in actions)
              SizedBox(
                width: _scrollTileWidth,
                child: _QuickActionTile(action: a),
              ),
          ],
        ),
      );
    }

    return Row(
      children: [
        for (final a in actions) Expanded(child: _QuickActionTile(action: a)),
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.action});

  final HomeQuickAction action;

  @override
  Widget build(BuildContext context) {
    final enabled = action.onTap != null;

    return Semantics(
      button: true,
      enabled: enabled,
      label: action.label,
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppUIConstants.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(
                          AppUIConstants.radiusLg,
                        ),
                      ),
                      child: Icon(
                        action.icon,
                        color: AppUIConstants.primary,
                        size: 24,
                      ),
                    ),
                    if (action.statusColor != null)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: action.statusColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppUIConstants.background,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  action.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppUIConstants.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
