import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/app_ui_constants.dart';
import '../../core/cubit/version_check_cubit.dart';

/// Splash screen shown on app launch: logo, tagline and a small loader on
/// white, matching the native launch screen.
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
  late final AnimationController _introController;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initialize();
  }

  void _setupAnimations() {
    _introController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _fade = CurvedAnimation(parent: _introController, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.92, end: 1).animate(
      CurvedAnimation(parent: _introController, curve: Curves.easeOutCubic),
    );
    _introController.forward();
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
    _introController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // White to match the native launch screen, so there is no colour flash.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppUIConstants.surface,
        body: SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  const Spacer(flex: 5),
                  ScaleTransition(scale: _scale, child: _buildLogo()),
                  const SizedBox(height: 20),
                  const Text(
                    'Smart living for every PG',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppUIConstants.textSecondary,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const Spacer(flex: 4),
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: AppUIConstants.accent,
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The logo file is a complete app icon (rounded tile, name, soft shadow on
  /// white), so it is shown as-is: no extra frame, crop or glow.
  Widget _buildLogo() {
    return Image.asset(
      'assets/images/app_logo.png',
      width: 200,
      height: 200,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => const SizedBox(
        width: 200,
        height: 200,
        child: Center(
          child: Text(
            'PG Sathi',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: AppUIConstants.primary,
              letterSpacing: -1,
            ),
          ),
        ),
      ),
    );
  }
}
