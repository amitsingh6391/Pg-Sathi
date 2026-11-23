import 'package:material_ui/material_ui.dart';

import '../app_ui_constants.dart';

/// One tab of [PremiumBottomNav].
class PremiumNavDestination {
  const PremiumNavDestination(this.icon, this.label, {this.badge = 0});

  final IconData icon;
  final String label;
  final int badge;
}

/// Full-width dark bar. The active tab gets a glowing indicator on the top
/// edge, a tinted icon well and a bold label; labels are always visible.
class PremiumBottomNav extends StatelessWidget {
  const PremiumBottomNav({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<PremiumNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        border: Border(top: BorderSide(color: AppUIConstants.border)),
        boxShadow: [AppUIConstants.shadowLg],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < destinations.length; i++)
                Expanded(
                  child: _NavItem(
                    destination: destinations[i],
                    selected: i == selectedIndex,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final PremiumNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? AppUIConstants.primaryLight
        : AppUIConstants.textTertiary;
    final icon = Icon(destination.icon, size: 22, color: color);

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: InkWell(
        onTap: onTap,
        child: ExcludeSemantics(
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                width: selected ? 36 : 0,
                height: 3,
                decoration: BoxDecoration(
                  color: AppUIConstants.primaryLight,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppUIConstants.primaryLight.withValues(
                        alpha: selected ? 0.6 : 0,
                      ),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppUIConstants.primarySoft
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(
                          AppUIConstants.radiusFull,
                        ),
                      ),
                      child: destination.badge > 0
                          ? Badge(
                              label: Text(
                                destination.badge > 99
                                    ? '99+'
                                    : '${destination.badge}',
                              ),
                              child: icon,
                            )
                          : icon,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      destination.label,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
