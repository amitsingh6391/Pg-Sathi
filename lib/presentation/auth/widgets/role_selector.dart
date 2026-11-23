import 'package:material_ui/material_ui.dart';
import 'package:unicons/unicons.dart';

import '../../../domain/entities/user.dart';
import '../../core/app_ui_constants.dart';

/// Side-by-side owner and student picker for the sign-in form.
class RoleSelector extends StatelessWidget {
  const RoleSelector({
    super.key,
    required this.selectedRole,
    required this.onChanged,
  });

  final UserRole selectedRole;
  final ValueChanged<UserRole> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _RoleTile(
            icon: UniconsLine.building,
            label: 'PG Owner',
            isSelected: selectedRole == UserRole.owner,
            onTap: () => onChanged(UserRole.owner),
          ),
        ),
        const SizedBox(width: AppUIConstants.spacingLg),
        Expanded(
          child: _RoleTile(
            icon: UniconsLine.bed,
            label: 'Resident',
            isSelected: selectedRole == UserRole.student,
            onTap: () => onChanged(UserRole.student),
          ),
        ),
      ],
    );
  }
}

class _RoleTile extends StatelessWidget {
  const _RoleTile({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected
        ? AppUIConstants.primary
        : AppUIConstants.border;
    final iconColor = isSelected
        ? AppUIConstants.primary
        : AppUIConstants.textSecondary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1),
        boxShadow: isSelected ? [AppUIConstants.shadowSm] : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
          child: Padding(
            padding: const EdgeInsets.all(AppUIConstants.spacingLg),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppUIConstants.primary
                            : AppUIConstants.background,
                        borderRadius: BorderRadius.circular(
                          AppUIConstants.radiusSm,
                        ),
                      ),
                      child: Icon(
                        icon,
                        size: 20,
                        color: isSelected ? AppUIConstants.surface : iconColor,
                      ),
                    ),
                    Icon(
                      isSelected
                          ? UniconsLine.check_circle
                          : UniconsLine.circle,
                      size: 20,
                      color: isSelected
                          ? AppUIConstants.accent
                          : AppUIConstants.disabled,
                    ),
                  ],
                ),
                const SizedBox(height: AppUIConstants.spacingMd),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    style: AppUIConstants.bodyLg.copyWith(
                      color: isSelected
                          ? AppUIConstants.primary
                          : AppUIConstants.textSecondary,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
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
