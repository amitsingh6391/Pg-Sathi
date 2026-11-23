import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection_container.dart';
import '../../core/app_ui_constants.dart';
import '../cubit/explore_libraries_cubit.dart';
import '../cubit/student_home_cubit.dart';
import '../cubit/student_home_state.dart';
import 'explore_libraries_screen.dart';
import 'student_home_screen.dart';
import 'student_notices_screen.dart';
import '../../core/widgets/premium_bottom_nav.dart';

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

  /// Switches to the Explore tab (index 1, only present when Explore is shown).
  void _openExploreTab() {
    if (!_homeCubit.state.canShowExploreLibraries) return;
    setState(() => _currentIndex = 1);
  }

  List<Widget> _getScreens(bool showExplore) {
    final screens = <Widget>[
      BlocProvider.value(
        value: _homeCubit,
        child: StudentHomeScreen(
          userId: widget.userId,
          onOpenExploreTab: _openExploreTab,
        ),
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
          return Scaffold(
            backgroundColor: AppUIConstants.background,
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppUIConstants.primarySoft,
                        ),
                        child: Icon(
                          Icons.campaign_rounded,
                          size: 38,
                          color: AppUIConstants.primaryLight,
                        ),
                      ),
                      SizedBox(height: 20),
                      Text('No notices yet', style: AppUIConstants.headingMd),
                      SizedBox(height: 8),
                      Text(
                        'Join a PG to get announcements from your owner here.',
                        style: AppUIConstants.bodyMd,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
            backgroundColor: AppUIConstants.background,
            extendBody: false,
            body: IndexedStack(index: safeIndex, children: screens),
            bottomNavigationBar: _buildBottomNavigationBar(showExplore),
          ),
        );
      },
    );
  }

  Widget _buildBottomNavigationBar(bool showExplore) {
    final items = [
      const PremiumNavDestination(Icons.home_rounded, 'Home'),
      if (showExplore)
        const PremiumNavDestination(Icons.explore_rounded, 'Explore'),
      const PremiumNavDestination(Icons.campaign_rounded, 'Notices'),
    ];

    return PremiumBottomNav(
      destinations: items,
      selectedIndex: _currentIndex.clamp(0, items.length - 1),
      onSelected: (i) => setState(() => _currentIndex = i),
    );
  }
}
