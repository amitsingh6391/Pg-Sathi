import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_ui_constants.dart';

/// Empty state view when no tenants are found.
class OccupiedSeatsEmptyView extends StatelessWidget {
  const OccupiedSeatsEmptyView({super.key, this.message, this.icon});

  final String? message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppUIConstants.border.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                icon ?? Icons.people_outline_rounded,
                size: 36,
                color: AppUIConstants.textTertiary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              message ?? 'No tenants',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppUIConstants.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tenants will appear here once assigned to a bed',
              style: TextStyle(
                fontSize: 14,
                color: AppUIConstants.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty state view when search returns no results.
class OccupiedSeatsSearchEmptyView extends StatelessWidget {
  const OccupiedSeatsSearchEmptyView({super.key, required this.searchQuery});

  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppUIConstants.border.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 36,
                color: AppUIConstants.textTertiary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No results',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppUIConstants.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No tenants match "$searchQuery"',
              style: TextStyle(
                fontSize: 14,
                color: AppUIConstants.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Error state view with retry button.
class OccupiedSeatsErrorView extends StatelessWidget {
  const OccupiedSeatsErrorView({
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
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppUIConstants.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.wifi_off_rounded,
                size: 36,
                color: AppUIConstants.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Failed to load',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppUIConstants.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: AppUIConstants.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onRetry();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppUIConstants.primary,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppUIConstants.primary.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Try again',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
