import 'package:flutter/material.dart';

/// Premium UI Constants for consistent, professional styling.
/// Uses a neutral color palette with a single accent color.
abstract class AppUIConstants {
  // =========================================================================
  // COLORS - Neutral Professional Palette
  // =========================================================================

  /// Primary brand color - simple charcoal
  static const Color primary = Color(0xFF1F2937);

  /// Primary variant - slightly lighter charcoal
  static const Color primaryLight = Color(0xFF374151);

  /// Secondary - slate grey
  static const Color secondary = Color(0xFF64748B);

  /// Single accent color - clean blue (used sparingly)
  static const Color accent = Color(0xFF2563EB);

  /// Success - subtle green
  static const Color success = Color(0xFF059669);

  /// Warning - muted amber
  static const Color warning = Color(0xFFD97706);

  /// Error - subdued red
  static const Color error = Color(0xFFDC2626);

  // =========================================================================
  // NEUTRAL GREYS - Typography & Background
  // =========================================================================

  /// Background - off white
  static const Color background = Color(0xFFF8FAFC);

  /// Surface - white cards
  static const Color surface = Color(0xFFFFFFFF);

  /// Border - subtle grey
  static const Color border = Color(0xFFE2E8F0);

  /// Divider
  static const Color divider = Color(0xFFF1F5F9);

  /// Text primary - charcoal
  static const Color textPrimary = Color(0xFF1E293B);

  /// Text secondary - grey
  static const Color textSecondary = Color(0xFF64748B);

  /// Text tertiary - light grey
  static const Color textTertiary = Color(0xFF94A3B8);

  /// Disabled
  static const Color disabled = Color(0xFFCBD5E1);

  // =========================================================================
  // CHART COLORS - Minimal, professional
  // =========================================================================

  /// Chart primary bar color
  static const Color chartPrimary = Color(0xFF475569);

  /// Chart secondary / accent
  static const Color chartAccent = accent;

  /// Chart grid lines
  static const Color chartGrid = Color(0xFFE2E8F0);

  /// Chart tooltip background
  static const Color chartTooltip = Color(0xFF1E293B);

  // =========================================================================
  // SPACING
  // =========================================================================

  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 12.0;
  static const double spacingLg = 16.0;
  static const double spacingXl = 20.0;
  static const double spacing2Xl = 24.0;
  static const double spacing3Xl = 32.0;

  // =========================================================================
  // BORDER RADIUS - Consistent 12-14
  // =========================================================================

  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 14.0;
  static const double radiusXl = 16.0;
  static const double radiusFull = 100.0;

  // =========================================================================
  // SHADOWS - Subtle
  // =========================================================================

  static BoxShadow get shadowSm => BoxShadow(
    color: Colors.black.withValues(alpha: 0.04),
    blurRadius: 8,
    offset: const Offset(0, 2),
  );

  static BoxShadow get shadowMd => BoxShadow(
    color: Colors.black.withValues(alpha: 0.06),
    blurRadius: 16,
    offset: const Offset(0, 4),
  );

  static BoxShadow get shadowLg => BoxShadow(
    color: Colors.black.withValues(alpha: 0.08),
    blurRadius: 24,
    offset: const Offset(0, 8),
  );

  // =========================================================================
  // CARD DECORATION - Standard
  // =========================================================================

  static BoxDecoration get cardDecoration => BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(radiusMd),
    boxShadow: [shadowMd],
  );

  static BoxDecoration get cardDecorationFlat => BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(radiusMd),
    border: Border.all(color: border),
  );

  // =========================================================================
  // TEXT STYLES
  // =========================================================================

  static const TextStyle headingLg = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle headingMd = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: -0.3,
  );

  static const TextStyle headingSm = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle bodyLg = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: textPrimary,
  );

  static const TextStyle bodyMd = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: textSecondary,
  );

  static const TextStyle bodySm = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: textSecondary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: textTertiary,
  );

  static const TextStyle labelMd = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: textSecondary,
  );

  static const TextStyle statValue = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: textPrimary,
  );

  // =========================================================================
  // APP BAR - Solid, no gradient
  // =========================================================================

  static BoxDecoration get appBarDecoration =>
      const BoxDecoration(color: primary);

  // =========================================================================
  // STATUS COLORS - Muted
  // =========================================================================

  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'complete':
      case 'checked_out':
        return success;
      case 'pending':
      case 'checked_in':
        return accent;
      case 'expired':
      case 'error':
        return error;
      default:
        return textSecondary;
    }
  }

  static Color getStatusBackgroundColor(String status) {
    return getStatusColor(status).withValues(alpha: 0.1);
  }

  // =========================================================================
  // BUTTON STYLES
  // =========================================================================

  static ButtonStyle get primaryButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: primary,
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusMd),
    ),
    padding: const EdgeInsets.symmetric(
      horizontal: spacingLg,
      vertical: spacingMd,
    ),
  );
}
