import 'package:material_ui/material_ui.dart';

import '../../core/app_ui_constants.dart';
import '../widgets/onboarding_page.dart';

/// Onboarding screen with 3 swipeable pages.
/// Shown only on first app launch.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onComplete});

  /// Callback when onboarding is completed or skipped.
  final VoidCallback onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const _pages = [
    OnboardingPageData(
      icon: Icons.apartment_rounded,
      title: 'Run your PG from one app',
      subtitle:
          'Room types, beds, residents, rent, deposits and notices - all in your pocket, no more messy registers.',
      highlight: 'Built for PGs and hostels',
      accent: AppUIConstants.primaryLight,
      orbitIcons: [
        Icons.king_bed_rounded,
        Icons.receipt_long_rounded,
        Icons.notifications_active_rounded,
      ],
    ),
    OnboardingPageData(
      icon: Icons.bed_rounded,
      title: 'Room types and beds, simplified',
      subtitle:
          'See vacant, occupied and reserved beds by room type, so live occupancy is always one glance away.',
      highlight: 'Live occupancy view',
      accent: AppUIConstants.primaryLight,
      orbitIcons: [
        Icons.meeting_room_rounded,
        Icons.event_available_rounded,
        Icons.groups_rounded,
      ],
    ),
    OnboardingPageData(
      icon: Icons.payments_rounded,
      title: 'Never miss a rent due',
      subtitle:
          'Record rent, deposits and part payments. Know exactly who has paid and who is pending.',
      highlight: 'Rent-first workflow',
      accent: AppUIConstants.primaryLight,
      orbitIcons: [
        Icons.currency_rupee_rounded,
        Icons.schedule_rounded,
        Icons.bar_chart_rounded,
      ],
    ),
    OnboardingPageData(
      icon: Icons.verified_user_rounded,
      title: 'Resident records, organised',
      subtitle:
          'Phone numbers, documents, stay details and check-in dates, safely kept in one place.',
      highlight: 'Start free',
      accent: AppUIConstants.primaryLight,
      orbitIcons: [
        Icons.badge_rounded,
        Icons.folder_shared_rounded,
        Icons.lock_rounded,
      ],
    ),
  ];

  bool get _isLastPage => _currentPage == _pages.length - 1;

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _nextPage() {
    if (_isLastPage) {
      widget.onComplete();
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _skip() {
    widget.onComplete();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = _pages[_currentPage].accent;
    return Scaffold(
      backgroundColor: AppUIConstants.background,
      body: Stack(
        children: [
          // Accent glow that cross-fades with the current page
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.55),
                  radius: 1.0,
                  colors: [
                    accent.withValues(alpha: 0.12),
                    AppUIConstants.background,
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _pageController,
              builder: (context, _) {
                final page =
                    _pageController.hasClients &&
                        _pageController.position.haveDimensions
                    ? (_pageController.page ?? 0.0)
                    : _currentPage.toDouble();
                return PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    return OnboardingPage(
                      data: _pages[index],
                      pageOffset: index - page,
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Column(
              children: [_buildHeader(), const Spacer(), _buildFooter()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 12, 0),
      child: Row(
        children: [
          Text(
            '${_currentPage + 1} / ${_pages.length}',
            style: const TextStyle(
              color: AppUIConstants.textTertiary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const Spacer(),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _isLastPage ? 0 : 1,
            child: TextButton(
              onPressed: _isLastPage ? null : _skip,
              style: TextButton.styleFrom(
                foregroundColor: AppUIConstants.textSecondary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              child: const Text(
                'Skip',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final accent = _pages[_currentPage].accent;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      child: Row(
        children: [
          _buildPageIndicator(accent),
          const Spacer(),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            height: 56,
            width: _isLastPage ? 190 : 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
              color: _isLastPage
                  ? AppUIConstants.accent
                  : AppUIConstants.primary,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
                onTap: _nextPage,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isLastPage ? 'Get Started' : 'Next',
                        style: const TextStyle(
                          color: AppUIConstants.background,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 20,
                        color: AppUIConstants.background,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator(Color accent) {
    return Row(
      children: List.generate(_pages.length, (index) {
        final active = _currentPage == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.only(right: 6),
          width: active ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? accent : AppUIConstants.disabled,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

/// Data model for onboarding page content.
class OnboardingPageData {
  const OnboardingPageData({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.highlight,
    this.accent = AppUIConstants.primaryLight,
    this.orbitIcons = const [],
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? highlight;

  /// Glow / illustration accent for this page.
  final Color accent;

  /// Small icons orbiting the main illustration.
  final List<IconData> orbitIcons;
}
