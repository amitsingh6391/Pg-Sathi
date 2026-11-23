import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection_container.dart';
import '../../auth/cubit/phone_auth_cubit.dart';
import '../bloc/owner_library_bloc.dart';
import '../bloc/owner_library_event.dart';
import '../bloc/owner_library_state.dart';
import 'owner_dashboard_screen.dart';
import 'owner_profile_wrapper.dart';
import 'owner_notices_screen.dart';
import '../../core/app_ui_constants.dart';
import '../../core/widgets/premium_bottom_nav.dart';
import '../../student/cubit/explore_libraries_cubit.dart';
import '../../student/screens/explore_libraries_screen.dart';

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
  late final ExploreLibrariesCubit _exploreCubit;
  bool _marketplaceLoaded = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<PhoneAuthCubit>().state.currentUser;
    _libraryBloc = sl<OwnerLibraryBloc>()
      ..add(
        LoadOwnerLibrary(
          ownerId: user?.ownerAccountId ?? '',
          managedLibraryIds: (user?.isManager ?? false)
              ? user!.managedLibraryIds
              : null,
        ),
      );
    _exploreCubit = sl<ExploreLibrariesCubit>();
  }

  @override
  void dispose() {
    _libraryBloc.close();
    _exploreCubit.close();
    super.dispose();
  }

  List<Widget> _getScreens(String ownerId, String libraryId) {
    return [
      BlocProvider.value(
        value: _libraryBloc,
        child: const OwnerDashboardScreen(),
      ),
      _buildNoticeBoardScreen(ownerId, libraryId),
      _buildMarketplaceScreen(ownerId),
      const OwnerProfileWrapper(),
    ];
  }

  /// PG marketplace — the same explore list residents see. Loads lazily on
  /// first build.
  Widget _buildMarketplaceScreen(String ownerId) {
    if (!_marketplaceLoaded) {
      _exploreCubit.loadLibraries();
      _marketplaceLoaded = true;
    }
    return BlocProvider.value(
      value: _exploreCubit,
      child: ExploreLibrariesScreen(userId: ownerId),
    );
  }

  Widget _buildNoticeBoardScreen(String ownerId, String libraryId) {
    if (libraryId.isEmpty) {
      return Scaffold(
        backgroundColor: AppUIConstants.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: AppUIConstants.primarySoft,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppUIConstants.primaryLight.withValues(
                          alpha: 0.35,
                        ),
                      ),
                    ),
                    child: const Icon(
                      Icons.campaign_rounded,
                      size: 32,
                      color: AppUIConstants.primaryLight,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Notices need a PG first',
                    style: AppUIConstants.headingMd,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Create your PG profile from Home, then post notices for '
                    'all your tenants here.',
                    style: AppUIConstants.bodyMd,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => setState(() => _currentIndex = 0),
                    icon: const Icon(Icons.home_work_rounded, size: 18),
                    label: const Text('Go to Home'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppUIConstants.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return OwnerNoticesScreen(libraryId: libraryId, ownerId: ownerId);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<PhoneAuthCubit>().state.currentUser;
    final ownerId = user?.ownerAccountId ?? '';

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
            backgroundColor: AppUIConstants.background,
            body: IndexedStack(index: _currentIndex, children: screens),
            bottomNavigationBar: _buildBottomNavigationBar(),
          ),
        );
      },
    );
  }

  Widget _buildBottomNavigationBar() {
    return PremiumBottomNav(
      destinations: const [
        PremiumNavDestination(Icons.space_dashboard_rounded, 'Home'),
        PremiumNavDestination(Icons.campaign_rounded, 'Notices'),
        PremiumNavDestination(Icons.storefront_rounded, 'Marketplace'),
        PremiumNavDestination(Icons.person_rounded, 'Profile'),
      ],
      selectedIndex: _currentIndex,
      onSelected: (i) => setState(() => _currentIndex = i),
    );
  }
}
