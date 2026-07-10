import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection_container.dart';
import '../../core/app_ui_constants.dart';
import '../../auth/cubit/phone_auth_cubit.dart';
import '../bloc/owner_library_bloc.dart';
import '../bloc/owner_library_event.dart';
import '../bloc/owner_library_state.dart';
import 'owner_dashboard_screen.dart';
import 'owner_profile_wrapper.dart';
import 'owner_notices_screen.dart';

/// Main navigation screen with bottom navigation bar for owners.
class OwnerMainNavigationScreen extends StatefulWidget {
  const OwnerMainNavigationScreen({super.key});

  @override
  State<OwnerMainNavigationScreen> createState() =>
      _OwnerMainNavigationScreenState();
}

class _OwnerMainNavigationScreenState extends State<OwnerMainNavigationScreen> {
  int _currentIndex = 0;
  late final OwnerLibraryBloc _libraryBloc;

  @override
  void initState() {
    super.initState();
    final user = context.read<PhoneAuthCubit>().state.currentUser;
    _libraryBloc = sl<OwnerLibraryBloc>()
      ..add(LoadOwnerLibrary(ownerId: user?.id ?? ''));
  }

  @override
  void dispose() {
    _libraryBloc.close();
    super.dispose();
  }

  List<Widget> _getScreens(String ownerId, String libraryId) {
    return [
      BlocProvider.value(
        value: _libraryBloc,
        child: const OwnerDashboardScreen(),
      ),
      _buildNoticeBoardScreen(ownerId, libraryId),
      const OwnerProfileWrapper(),
    ];
  }

  Widget _buildNoticeBoardScreen(String ownerId, String libraryId) {
    if (libraryId.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Please create your PG profile first')),
      );
    }

    return OwnerNoticesScreen(libraryId: libraryId, ownerId: ownerId);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<PhoneAuthCubit>().state.currentUser;
    final ownerId = user?.id ?? '';

    return BlocBuilder<OwnerLibraryBloc, OwnerLibraryState>(
      bloc: _libraryBloc,
      builder: (context, state) {
        final libraryId = state.library?.id ?? '';
        final screens = _getScreens(ownerId, libraryId);

        // Prevent system back from popping the root route (crashes go_router).
        // Standard UX: back on non-Home tab → switch to Home; back on Home → no-op.
        final isOnHomeTab = _currentIndex == 0;
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && !isOnHomeTab) {
              setState(() => _currentIndex = 0);
            }
          },
          child: Scaffold(
            body: IndexedStack(index: _currentIndex, children: screens),
            bottomNavigationBar: _buildBottomNavigationBar(),
          ),
        );
      },
    );
  }

  Widget _buildBottomNavigationBar() {
    final items = [
      _NavItemData(Icons.dashboard_rounded, 'Home', 0),
      _NavItemData(Icons.campaign_rounded, 'Notices', 1),
      _NavItemData(Icons.person_rounded, 'Profile', 2),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.only(
          top: 8.0,
          bottom: 8.0,
          left: 4.0,
          right: 4.0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: items
              .map(
                (item) => _buildNavItem(
                  icon: item.icon,
                  label: item.label,
                  index: item.index,
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? AppUIConstants.primary : Colors.grey[600];

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 26, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  const _NavItemData(this.icon, this.label, this.index);
  final IconData icon;
  final String label;
  final int index;
}
