import 'package:material_ui/material_ui.dart';

import '../../../core/app_ui_constants.dart';

/// Horizontal chips for choosing which membership the header card shows.
class HomeMembershipSwitcher extends StatelessWidget {
  const HomeMembershipSwitcher({
    super.key,
    required this.items,
    required this.selectedId,
    required this.onSelected,
  });

  final List<({String id, String label})> items;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final item = items[index];
          final selected = item.id == selectedId;

          return Semantics(
            button: true,
            selected: selected,
            label: item.label,
            child: InkWell(
              onTap: () => onSelected(item.id),
              borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 180),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(
                    AppUIConstants.radiusFull,
                  ),
                ),
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? AppUIConstants.primary : Colors.white,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
