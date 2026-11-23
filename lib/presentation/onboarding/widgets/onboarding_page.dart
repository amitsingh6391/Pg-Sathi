import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/app_ui_constants.dart';
import '../screens/onboarding_screen.dart';

/// Full-bleed onboarding page: a layered illustration built from shapes and
/// icons on top, copy anchored to the bottom (above the footer controls).
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.data, this.pageOffset = 0});

  final OnboardingPageData data;

  /// Distance from the centre of the pager (0 = fully visible); drives parallax.
  final double pageOffset;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final off = widget.pageOffset.clamp(-1.0, 1.0);
    final fade = (1 - off.abs()).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 56),
          Expanded(
            child: Transform.translate(
              offset: Offset(off * 90, 0),
              child: Opacity(
                opacity: fade,
                child: Center(child: _buildIllustration(data)),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Transform.translate(
            offset: Offset(off * 40, 0),
            child: Opacity(
              opacity: fade,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (data.highlight != null) ...[
                    _buildHighlight(data),
                    const SizedBox(height: 14),
                  ],
                  Text(
                    data.title,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppUIConstants.textPrimary,
                      height: 1.1,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    data.subtitle,
                    style: const TextStyle(
                      fontSize: 15.5,
                      color: AppUIConstants.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIllustration(OnboardingPageData data) {
    final accent = data.accent;
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, c) {
          final size = math.min(c.maxWidth, c.maxHeight);
          final center = size / 2;
          return AnimatedBuilder(
            animation: _float,
            builder: (context, _) {
              final angle = _float.value * 2 * math.pi;
              return Stack(
                alignment: Alignment.center,
                children: [
                  for (final f in const [1.0, 0.72, 0.46])
                    Container(
                      width: size * f,
                      height: size * f,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accent.withValues(alpha: 0.10 + (1 - f) * 0.2),
                        ),
                        color: accent.withValues(alpha: (1 - f) * 0.06),
                      ),
                    ),
                  // Orbiting chips
                  for (var i = 0; i < data.orbitIcons.length; i++)
                    Builder(
                      builder: (context) {
                        final a =
                            angle * (i.isEven ? 1 : -1) * 0.5 +
                            i * 2 * math.pi / data.orbitIcons.length;
                        final r = size * (i == 1 ? 0.36 : 0.5) - 22;
                        return Positioned(
                          left: center + r * math.cos(a) - 22,
                          top: center + r * math.sin(a) - 22,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppUIConstants.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppUIConstants.border),
                            ),
                            child: Icon(
                              data.orbitIcons[i],
                              size: 22,
                              color: AppUIConstants.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  // Hero tile
                  Transform.translate(
                    offset: Offset(0, math.sin(angle) * 6),
                    child: Container(
                      width: size * 0.38,
                      height: size * 0.38,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(size * 0.1),
                        color: AppUIConstants.primary,
                      ),
                      child: Icon(
                        data.icon,
                        size: size * 0.18,
                        color: AppUIConstants.background,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHighlight(OnboardingPageData data) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: data.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppUIConstants.radiusFull),
        border: Border.all(color: data.accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, size: 15, color: data.accent),
          const SizedBox(width: 4),
          Text(
            data.highlight!,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: data.accent,
            ),
          ),
        ],
      ),
    );
  }
}
