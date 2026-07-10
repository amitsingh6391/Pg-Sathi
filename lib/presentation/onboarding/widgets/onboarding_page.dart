import 'package:flutter/material.dart';

import '../../core/app_ui_constants.dart';
import '../screens/onboarding_screen.dart';

/// Reusable onboarding page widget.
/// Displays icon, title, subtitle, and optional highlight text.
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key, required this.data});

  final OnboardingPageData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 1),

          // Icon Container
          _buildIconContainer(),

          const SizedBox(height: 48),

          // Title
          Text(
            data.title,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1F36),
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          // Subtitle
          Text(
            data.subtitle,
            style: TextStyle(
              fontSize: 16,
              color: AppUIConstants.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),

          // Highlight (optional)
          if (data.highlight != null) ...[
            const SizedBox(height: 20),
            _buildHighlight(data.highlight!),
          ],

          const Spacer(flex: 2),
        ],
      ),
    );
  }

  Widget _buildIconContainer() {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        color: AppUIConstants.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Icon(data.icon, size: 64, color: AppUIConstants.primary),
    );
  }

  Widget _buildHighlight(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 16,
            color: Color(0xFF10B981),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF10B981),
            ),
          ),
        ],
      ),
    );
  }
}
