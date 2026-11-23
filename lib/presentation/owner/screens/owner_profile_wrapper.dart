import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection_container.dart';
import '../../../domain/entities/library.dart';
import '../../auth/cubit/phone_auth_cubit.dart';
import '../../auth/cubit/phone_auth_state.dart';
import '../../core/app_ui_constants.dart';
import '../../student/cubit/profile_cubit.dart';
import '../../student/screens/profile_screen.dart';
import '../bloc/owner_library_bloc.dart';
import '../bloc/owner_library_event.dart';
import 'library_form_screen.dart';

/// Wrapper to handle profile screen for owners in navigation.
class OwnerProfileWrapper extends StatelessWidget {
  const OwnerProfileWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PhoneAuthCubit, PhoneAuthState>(
      builder: (context, authState) {
        return authState.maybeWhen(
          authenticated: (user) => BlocProvider(
            create: (_) => sl<ProfileCubit>(),
            child: ProfileScreen(user: user),
          ),
          orElse: () => const Scaffold(
            backgroundColor: AppUIConstants.background,
            body: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppUIConstants.primaryLight,
              ),
            ),
          ),
        );
      },
    );
  }

  /// Navigates to the PG form in create-new-branch mode, then reloads the
  /// branch list so the new PG shows up in the switcher.
  static Future<void> _navigateToAddBranch(
    NavigatorState navigator,
    PhoneAuthCubit authCubit,
    OwnerLibraryBloc libraryBloc,
  ) async {
    final user = authCubit.state.currentUser;
    if (user == null) return;

    final result = await navigator.push<bool>(
      MaterialPageRoute(
        builder: (_) => LibraryFormScreen(
          ownerId: user.ownerAccountId,
          ownerPhone: user.phone,
          forceCreate: true,
        ),
      ),
    );

    if (result == true && !libraryBloc.isClosed) {
      libraryBloc.add(LoadOwnerLibrary(ownerId: user.ownerAccountId));
    }
  }

  /// Shows branch switcher bottom sheet.
  static void showBranchSwitcher(BuildContext context) {
    final libraryState = context.read<OwnerLibraryBloc>().state;
    if (!libraryState.hasMultipleLibraries) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return BlocProvider.value(
          value: context.read<OwnerLibraryBloc>(),
          child: _BranchSwitcherSheet(
            libraries: libraryState.libraries,
            selectedIndex: libraryState.selectedLibraryIndex,
            isManager:
                context.read<PhoneAuthCubit>().state.currentUser?.isManager ??
                false,
          ),
        );
      },
    );
  }
}

class _BranchSwitcherSheet extends StatelessWidget {
  const _BranchSwitcherSheet({
    required this.libraries,
    required this.selectedIndex,
    required this.isManager,
  });

  final List<Library> libraries;
  final int selectedIndex;

  /// Managers can switch between their branches but not add new ones.
  final bool isManager;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Switch Branch',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppUIConstants.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Select a branch to manage',
              style: TextStyle(
                fontSize: 14,
                color: AppUIConstants.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(libraries.length, (index) {
              final library = libraries[index];
              final isSelected = index == selectedIndex;
              return _BranchTile(
                name: library.name,
                isSelected: isSelected,
                onTap: isSelected
                    ? null
                    : () {
                        context.read<OwnerLibraryBloc>().add(
                          SelectLibrary(index: index),
                        );
                        Navigator.of(context).pop();
                      },
              );
            }),
            if (!isManager) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    final navigator = Navigator.of(context);
                    final authCubit = context.read<PhoneAuthCubit>();
                    final libraryBloc = context.read<OwnerLibraryBloc>();
                    navigator.pop();
                    OwnerProfileWrapper._navigateToAddBranch(
                      navigator,
                      authCubit,
                      libraryBloc,
                    );
                  },
                  icon: const Icon(Icons.add_business_rounded, size: 18),
                  label: const Text('Add New Branch'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppUIConstants.primary,
                    side: BorderSide(color: AppUIConstants.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BranchTile extends StatelessWidget {
  const _BranchTile({required this.name, required this.isSelected, this.onTap});

  final String name;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? AppUIConstants.primary.withValues(alpha: 0.1)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppUIConstants.primary : Colors.grey.shade200,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: 22,
                color: isSelected
                    ? AppUIConstants.primary
                    : Colors.grey.shade400,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? AppUIConstants.primary
                        : AppUIConstants.textPrimary,
                  ),
                ),
              ),
              if (isSelected)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppUIConstants.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Active',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
