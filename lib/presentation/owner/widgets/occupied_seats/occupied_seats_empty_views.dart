import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../../../core/app_ui_constants.dart';

/// Shared icon + title + body + optional CTA layout for list states.
class _StateView extends StatelessWidget {
  const _StateView({
    required this.icon,
    required this.title,
    required this.body,
    this.color = AppUIConstants.primaryLight,
    this.actionLabel,
    this.actionIcon = Icons.refresh_rounded,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color color;
  final String? actionLabel;
  final IconData actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.12),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Icon(icon, size: 38, color: color),
            ),
            const SizedBox(height: 22),
            Text(title, style: AppUIConstants.headingMd),
            const SizedBox(height: 8),
            Text(
              body,
              style: AppUIConstants.bodyMd,
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 22),
              ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onAction!();
                },
                icon: Icon(actionIcon, size: 18),
                label: Text(actionLabel!),
                style: AppUIConstants.primaryButtonStyle.copyWith(
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppUIConstants.radiusFull,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Empty state view when no residents are found.
class OccupiedSeatsEmptyView extends StatelessWidget {
  const OccupiedSeatsEmptyView({
    super.key,
    this.message,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String? message;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return _StateView(
      icon: icon ?? Icons.bed_rounded,
      title: message ?? 'No residents',
      body: 'Residents will appear here once they are assigned to a bed',
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}

/// Empty state view when search returns no results.
class OccupiedSeatsSearchEmptyView extends StatelessWidget {
  const OccupiedSeatsSearchEmptyView({
    super.key,
    required this.searchQuery,
    this.onClear,
  });

  final String searchQuery;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return _StateView(
      icon: Icons.search_off_rounded,
      title: 'No results',
      body: 'No residents match "$searchQuery"',
      actionLabel: 'Clear search',
      actionIcon: Icons.close_rounded,
      onAction: onClear,
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
    return _StateView(
      icon: Icons.wifi_off_rounded,
      title: 'Failed to load',
      body: message,
      color: AppUIConstants.error,
      actionLabel: 'Try again',
      onAction: onRetry,
    );
  }
}
