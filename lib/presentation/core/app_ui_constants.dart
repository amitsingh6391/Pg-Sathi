import 'package:material_ui/material_ui.dart';

/// Premium UI Constants for consistent, professional styling.
/// Uses a neutral color palette with a single accent color.
abstract class AppUIConstants {
  // =========================================================================
  // COLORS - Neutral Professional Palette
  // =========================================================================

  /// Primary brand color - Deep indigo
  static const Color primary = Color(0xFF312E81);

  /// Primary variant - slightly lighter
  static const Color primaryLight = Color(0xFF3730A3);

  /// Secondary - slate grey
  static const Color secondary = Color(0xFF64748B);

  /// Single accent color - Indigo (used sparingly)
  static const Color accent = Color(0xFF4F46E5);

  /// Success - subtle green
  static const Color success = Color(0xFF059669);

  /// Warning - muted amber
  static const Color warning = Color(0xFFD97706);

  /// Error - subdued red
  static const Color error = Color(0xFFDC2626);

  /// Pending owner approval - violet
  static const Color approval = Color(0xFF8B5CF6);

  /// Premium subscriber highlight - gold
  static const Color premiumGold = Color(0xFFFFD700);

  /// Skeleton loading placeholders (base, shimmer highlight)
  static const Color skeletonBase = Color(0xFFECEEF8);
  static const Color skeletonHighlight = Color(0xFFDCDFF2);

  // =========================================================================
  // NEUTRAL GREYS - Typography & Background
  // =========================================================================

  /// Background - white
  static const Color background = Color(0xFFFFFFFF);

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

  // =========================================================================
  // STATUS COLORS - Muted
  // =========================================================================

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

  static ButtonStyle get secondaryButtonStyle => OutlinedButton.styleFrom(
    foregroundColor: primary,
    side: const BorderSide(color: border),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusMd),
    ),
    padding: const EdgeInsets.symmetric(
      horizontal: spacingLg,
      vertical: spacingMd,
    ),
  );

  // =========================================================================
  // PG SATHI EXTRAS (tints derived from the indigo palette above)
  // =========================================================================

  /// Pale indigo tint for selected states and icon chips.
  static const Color primarySoft = Color(0xFFEEF2FF);

  /// Soft indigo tint for accent highlights.
  static const Color accentSoft = Color(0xFFE0E7FF);

  /// Muted surface for inset fields, chips and skeletons.
  static const Color surfaceMuted = Color(0xFFF1F5F9);

  /// Header band colors (white, matching the white theme).
  static const List<Color> heroColors = [surface, surface];

  static const double spacing3Xl = 32.0;

  /// Accent call-to-action button.
  static ButtonStyle get accentButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: accent,
    foregroundColor: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusMd),
    ),
    padding: const EdgeInsets.symmetric(horizontal: spacingXl, vertical: 14),
  );

  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'complete':
      case 'paid':
      case 'occupied':
      case 'checked_out':
        return success;
      case 'pending':
      case 'due':
      case 'notice':
      case 'checked_in':
        return warning;
      case 'vacant':
        return accent;
      case 'expired':
      case 'overdue':
      case 'error':
        return error;
      default:
        return textSecondary;
    }
  }

  static Color getStatusBackgroundColor(String status) =>
      getStatusColor(status).withValues(alpha: 0.1);
}
