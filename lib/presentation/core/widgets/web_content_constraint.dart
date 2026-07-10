import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Maximum content width for web platforms.
/// This creates a tablet-like experience on large screens.
const double kMaxContentWidth = 1024.0;

/// Horizontal padding applied to the centered content container.
const double kContentHorizontalPadding = 24.0;

/// A widget that constrains content width on web platforms.
///
/// On web, this creates a centered, max-width container that prevents
/// UI stretching on large screens while maintaining a premium tablet-like
/// appearance. On mobile platforms, it renders the child without constraints.
///
/// Usage:
/// This widget is used as a ShellRoute builder in GoRouter to wrap app screens
/// (owner, student, admin) while allowing full-width marketing pages (landing).
class WebContentConstraint extends StatelessWidget {
  const WebContentConstraint({
    super.key,
    required this.child,
    this.maxWidth = kMaxContentWidth,
    this.backgroundColor,
  });

  /// The child widget to constrain.
  final Widget child;

  /// Maximum width of the content area on web.
  /// Defaults to [kMaxContentWidth] (1024px).
  final double maxWidth;

  /// Optional background color for the area outside the content.
  /// If null, uses the scaffold background color from the theme.
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    // On mobile platforms, render child without constraints
    if (!kIsWeb) {
      return child;
    }

    // On web, apply max-width constraint with centered layout
    final theme = Theme.of(context);
    final bgColor = backgroundColor ?? theme.scaffoldBackgroundColor;

    return ColoredBox(
      color: bgColor,
      child: Center(
        child: SizedBox(
          width: maxWidth,
          child: child,
        ),
      ),
    );
  }
}

/// A shell widget for GoRouter that applies web content constraints.
///
/// This is used as a ShellRoute builder to wrap app screens with the
/// max-width constraint on web while allowing other routes (like the
/// landing page) to remain full-width.
class WebConstrainedShell extends StatelessWidget {
  const WebConstrainedShell({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return WebContentConstraint(child: child);
  }
}
