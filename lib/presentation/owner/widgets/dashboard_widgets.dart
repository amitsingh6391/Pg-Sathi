import 'package:flutter/material.dart';

import '../../core/app_ui_constants.dart';

/// Empty PG profile state card.
class EmptyLibraryCard extends StatelessWidget {
  const EmptyLibraryCard({super.key, required this.onCreateLibrary});

  final VoidCallback onCreateLibrary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppUIConstants.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppUIConstants.primary.withValues(alpha: 0.1),
                  AppUIConstants.accent.withValues(alpha: 0.05),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.apartment_rounded,
              size: 40,
              color: AppUIConstants.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Setup Your PG',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppUIConstants.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your PG profile to start\nmanaging tenants, rooms, and beds',
            style: TextStyle(
              fontSize: 13,
              color: AppUIConstants.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onCreateLibrary,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppUIConstants.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Get Started',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Error view for dashboard - Minimal design.
class DashboardErrorView extends StatelessWidget {
  const DashboardErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppUIConstants.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.wifi_off_rounded,
                size: 32,
                color: AppUIConstants.error,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppUIConstants.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: AppUIConstants.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: TextButton.styleFrom(
                foregroundColor: AppUIConstants.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardLoading extends StatefulWidget {
  const DashboardLoading({super.key});

  @override
  State<DashboardLoading> createState() => _DashboardLoadingState();
}

class _DashboardLoadingState extends State<DashboardLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _anim = Tween<double>(
      begin: -2,
      end: 2,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SkeletonBox(width: double.infinity, height: 120, anim: _anim),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _SkeletonBox(height: 88, anim: _anim)),
              const SizedBox(width: 12),
              Expanded(child: _SkeletonBox(height: 88, anim: _anim)),
              const SizedBox(width: 12),
              Expanded(child: _SkeletonBox(height: 88, anim: _anim)),
            ],
          ),
          const SizedBox(height: 16),
          _SkeletonBox(width: double.infinity, height: 64, anim: _anim),
          const SizedBox(height: 12),
          _SkeletonBox(width: double.infinity, height: 64, anim: _anim),
          const SizedBox(height: 16),
          _SkeletonBox(width: 140, height: 18, anim: _anim),
          const SizedBox(height: 10),
          _SkeletonBox(width: double.infinity, height: 100, anim: _anim),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({required this.anim, required this.height, this.width});

  final Animation<double> anim;
  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment(anim.value - 1, 0),
          end: Alignment(anim.value + 1, 0),
          colors: const [
            Color(0xFFE8EEF4),
            Color(0xFFD0DCE8),
            Color(0xFFE8EEF4),
          ],
        ),
      ),
    );
  }
}
