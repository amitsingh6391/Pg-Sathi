import 'package:flutter/material.dart';

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
      title: 'Run Your PG From One App',
      subtitle:
          'Manage rooms, beds, tenants, rent, deposits, notices, and reports without messy registers.',
      highlight: 'Built for PGs and hostels',
    ),
    OnboardingPageData(
      icon: Icons.bed_rounded,
      title: 'Rooms & Beds Made Simple',
      subtitle:
          'Track available, occupied, and reserved beds room-wise so you always know your live occupancy.',
      highlight: 'Live occupancy view',
    ),
    OnboardingPageData(
      icon: Icons.payments_rounded,
      title: 'Never Miss Rent Dues',
      subtitle:
          'Record rent, security deposits, partial payments, and pending dues with clear owner reports.',
      highlight: 'Rent-first workflow',
    ),
    OnboardingPageData(
      icon: Icons.verified_user_rounded,
      title: 'Tenant Records In One Place',
      subtitle:
          'Keep tenant phone numbers, documents, stay details, check-in dates, and notices organized.',
      highlight: 'Start free',
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
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFC),
      body: SafeArea(
        child: Column(
          children: [
            // Skip Button
            _buildHeader(),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return OnboardingPage(data: _pages[index]);
                },
              ),
            ),

            // Page Indicator & CTA
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _skip,
            style: TextButton.styleFrom(
              foregroundColor: AppUIConstants.textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text(
              'Skip',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        children: [
          // Page Indicator
          _buildPageIndicator(),

          const SizedBox(height: 32),

          // CTA Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _nextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppUIConstants.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: Text(
                _isLastPage ? 'Get Started' : 'Next',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _pages.length,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: _currentPage == index ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: _currentPage == index
                ? AppUIConstants.primary
                : AppUIConstants.primary.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
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
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? highlight;
}
