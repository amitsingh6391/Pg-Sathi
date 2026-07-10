import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/app_ui_constants.dart';
import '../../core/cubit/version_check_cubit.dart';

/// Splash screen shown on app launch.
/// Minimal, professional design with logo and tagline.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onInitializationComplete});

  /// Callback when splash initialization is complete.
  /// Returns true if onboarding should be shown (first launch).
  final Future<bool> Function() onInitializationComplete;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initialize();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _fadeController.forward();
  }

  Future<void> _initialize() async {
    // Wait for minimum splash duration (matches 800ms fade-in + buffer)
    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted || _hasNavigated) return;

    // Wait for version check to complete
    await _waitForVersionCheck();

    if (!mounted || _hasNavigated) return;

    // Check version status before navigating
    final versionCheckCubit = context.read<VersionCheckCubit>();
    final versionState = versionCheckCubit.state;

    // If update is required, don't navigate - dialog will be shown by VersionCheckWrapper
    if (versionState.isUpdateRequired) {
      return;
    }

    // Proceed with navigation only if no update is required
    if (mounted && !_hasNavigated) {
      _hasNavigated = true;
      await widget.onInitializationComplete();
    }
  }

  Future<void> _waitForVersionCheck() async {
    final versionCheckCubit = context.read<VersionCheckCubit>();
    int attempts = 0;
    const maxAttempts = 30; // Wait up to 3 seconds (30 * 100ms)

    while (attempts < maxAttempts && mounted) {
      final state = versionCheckCubit.state;

      // If check is complete (either update required or not), break
      if (!state.isChecking) {
        break;
      }

      // Poll frequently — this is just checking local state, not I/O
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFC),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(flex: 3),

                // Logo
                _buildLogo(),

                const SizedBox(height: 20),

                // App Name
                Text(
                  'PG Sathi',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppUIConstants.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),

                const SizedBox(height: 8),

                // Tagline
                Text(
                  'Manage your PG or hostel. Smartly.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: AppUIConstants.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                ),

                const Spacer(flex: 3),

                // Loading Indicator
                _buildLoadingIndicator(),

                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppUIConstants.primary.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Image.asset(
          'assets/images/app_logo.png',
          width: 100,
          height: 100,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Column(
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(
              AppUIConstants.primary.withValues(alpha: 0.7),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Loading...',
          style: TextStyle(fontSize: 13, color: AppUIConstants.textTertiary),
        ),
      ],
    );
  }
}
