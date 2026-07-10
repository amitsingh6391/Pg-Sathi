import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection_container.dart';
import '../../core/app_ui_constants.dart';
import '../cubit/explore_libraries_cubit.dart';
import '../cubit/student_home_cubit.dart';
import '../cubit/student_home_state.dart';
import 'explore_libraries_screen.dart';
import 'student_home_screen.dart';
import 'student_notices_screen.dart';

/// Main navigation screen with bottom navigation bar for students.
class StudentMainNavigationScreen extends StatefulWidget {
  const StudentMainNavigationScreen({super.key, required this.userId});

  final String userId;

  @override
  State<StudentMainNavigationScreen> createState() =>
      _StudentMainNavigationScreenState();
}

class _StudentMainNavigationScreenState
    extends State<StudentMainNavigationScreen> {
  int _currentIndex = 0;

  late final StudentHomeCubit _homeCubit;
  late final ExploreLibrariesCubit _exploreCubit;

  bool _exploreLoaded = false;

  @override
  void initState() {
    super.initState();
    _homeCubit = sl<StudentHomeCubit>()..loadDashboard(userId: widget.userId);
    _exploreCubit = sl<ExploreLibrariesCubit>();
  }

  @override
  void dispose() {
    _homeCubit.close();
    _exploreCubit.close();
    super.dispose();
  }

  List<Widget> _getScreens(bool showExplore) {
    final screens = <Widget>[
      BlocProvider.value(
        value: _homeCubit,
        child: StudentHomeScreen(userId: widget.userId),
      ),
    ];

    if (showExplore) {
      // Lazy-load: only call loadLibraries once when explore becomes available
      if (!_exploreLoaded) {
        _exploreCubit.loadLibraries();
        _exploreLoaded = true;
      }
      screens.add(
        BlocProvider.value(
          value: _exploreCubit,
          child: ExploreLibrariesScreen(userId: widget.userId),
        ),
      );
    }

    screens.add(_buildNoticeBoardScreen());

    return screens;
  }

  Widget _buildNoticeBoardScreen() {
    return BlocBuilder<StudentHomeCubit, StudentHomeState>(
      bloc: _homeCubit,
      builder: (context, state) {
        final libraryIds = state.memberships
            .map((m) => m.membership.libraryId)
            .toSet()
            .toList();

        if (libraryIds.isEmpty) {
          return const Scaffold(
            body: Center(child: Text('No active PG stay found')),
          );
        }

        return StudentNoticesScreen(
          libraryIds: libraryIds,
          studentId: widget.userId,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StudentHomeCubit, StudentHomeState>(
      bloc: _homeCubit,
      builder: (context, state) {
        final showExplore = state.canShowExploreLibraries;
        final screens = _getScreens(showExplore);

        final safeIndex = _currentIndex.clamp(0, screens.length - 1);

        // Prevent system back from popping the root route (crashes go_router).
        // Standard UX: back on non-Home tab -> switch to Home; back on Home -> no-op.
        final isOnHomeTab = safeIndex == 0;
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && !isOnHomeTab) {
              setState(() => _currentIndex = 0);
            }
          },
          child: Scaffold(
            body: IndexedStack(index: safeIndex, children: screens),
            bottomNavigationBar: _buildBottomNavigationBar(showExplore),
          ),
        );
      },
    );
  }

  Widget _buildBottomNavigationBar(bool showExplore) {
    int idx = 0;
    final items = [
      _NavItemData(Icons.home_rounded, 'Home', idx++),
      if (showExplore) _NavItemData(Icons.apartment_rounded, 'PGs', idx++),
      _NavItemData(Icons.campaign_rounded, 'Notices', idx++),
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
