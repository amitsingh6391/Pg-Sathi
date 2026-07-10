import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:unicons/unicons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/current_affair.dart';
import '../../../domain/entities/user.dart';
import '../../core/app_ui_constants.dart';

// =============================================================================
// Header — Compact with primary background
// =============================================================================

/// Compact header bar with primary background, profile pic, name, and actions.
class StudentDashboardHeader extends StatelessWidget {
  const StudentDashboardHeader({
    super.key,
    required this.user,
    required this.onRefresh,
    required this.onSignOut,
    this.onProfile,
  });

  final User? user;
  final VoidCallback onRefresh;
  final VoidCallback? onProfile;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final displayName = user?.displayName ?? 'Reader';
    final avatarUrl = user?.avatarUrl;

    return Container(
      color: AppUIConstants.primary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(
            children: [
              _Avatar(
                avatarUrl: avatarUrl,
                initials: user?.initials ?? 'U',
                onTap: onProfile,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(
                  UniconsLine.refresh,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: onRefresh,
                tooltip: 'Refresh',
                visualDensity: VisualDensity.compact,
              ),
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert,
                  color: Colors.white,
                  size: 22,
                ),
                color: AppUIConstants.surface,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppUIConstants.radiusMd),
                ),
                onSelected: (v) {
                  if (v == 'signout') onSignOut();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'signout',
                    child: Row(
                      children: [
                        Icon(
                          UniconsLine.signout,
                          size: 20,
                          color: AppUIConstants.error,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Sign Out',
                          style:
                              TextStyle(color: AppUIConstants.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.avatarUrl, required this.initials, this.onTap});
  final String? avatarUrl;
  final String initials;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: ClipOval(
          child: avatarUrl != null && avatarUrl!.isNotEmpty
              ? Image.network(
                  avatarUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _fallback(),
                )
              : _fallback(),
        ),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      color: Colors.white.withValues(alpha: 0.15),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Section Header
// =============================================================================

/// Reusable section header with accent bar and optional action.
class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.onViewAll,
  });

  final String title;
  final Widget? trailing;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            color: AppUIConstants.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: AppUIConstants.headingSm.copyWith(
            fontSize: 15,
            letterSpacing: -0.2,
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing!,
        if (onViewAll != null)
          GestureDetector(
            onTap: onViewAll,
            child: Text(
              'View All',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppUIConstants.accent,
              ),
            ),
          ),
      ],
    );
  }
}

// =============================================================================
// Latest News Cards
// =============================================================================

/// Horizontal scrollable list of latest current affairs cards.
class LatestNewsCards extends StatelessWidget {
  const LatestNewsCards({
    super.key,
    required this.articles,
    required this.onArticleTap,
    required this.onViewAll,
  });

  final List<CurrentAffair> articles;
  final void Function(CurrentAffair) onArticleTap;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    if (articles.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        HomeSectionHeader(title: 'Latest News', onViewAll: onViewAll),
        const SizedBox(height: 12),
        SizedBox(
          height: 152,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: articles.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return _NewsCard(
                article: articles[index],
                onTap: () => onArticleTap(articles[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.article, required this.onTap});

  final CurrentAffair article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dateStr = article.publishedAt != null
        ? DateFormat('dd MMM').format(article.publishedAt!)
        : '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppUIConstants.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppUIConstants.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category + date row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _categoryColor(
                      article.category,
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    article.categoryLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _categoryColor(article.category),
                    ),
                  ),
                ),
                const Spacer(),
                if (dateStr.isNotEmpty)
                  Text(dateStr, style: AppUIConstants.caption),
              ],
            ),
            const SizedBox(height: 10),

            // Title
            Text(
              article.title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppUIConstants.textPrimary,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),

            // Summary
            Text(
              article.summary,
              style: AppUIConstants.bodySm,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Color _categoryColor(CurrentAffairsCategory cat) {
    return switch (cat) {
      CurrentAffairsCategory.national => const Color(0xFF3B82F6),
      CurrentAffairsCategory.international => const Color(0xFF8B5CF6),
      CurrentAffairsCategory.economy => const Color(0xFF10B981),
      CurrentAffairsCategory.science => const Color(0xFFF59E0B),
      CurrentAffairsCategory.environment => const Color(0xFF059669),
      CurrentAffairsCategory.sports => const Color(0xFFEC4899),
      CurrentAffairsCategory.defense => const Color(0xFF6366F1),
      CurrentAffairsCategory.polity => const Color(0xFF0EA5E9),
      CurrentAffairsCategory.other => AppUIConstants.accent,
    };
  }
}

// =============================================================================
// Partner Slider — Auto-scrolling carousel for affiliate partners
// =============================================================================

/// Auto-scrolling PageView of affiliate partner cards.
/// Fires [onCouponCopied] with the partner when a coupon code is copied.
class PartnerSlider extends StatefulWidget {
  const PartnerSlider({super.key, this.onCouponCopied});

  final void Function(AffiliatePartner partner)? onCouponCopied;

  @override
  State<PartnerSlider> createState() => _PartnerSliderState();
}

class _PartnerSliderState extends State<PartnerSlider> {
  late final PageController _controller;
  int _currentPage = 0;
  Timer? _autoScrollTimer;

  List<AffiliatePartner> get _partners => AppConstants.affiliatePartners;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 1.0);
    _startAutoScroll();
  }

  void _startAutoScroll() {
    if (_partners.length <= 1) return;
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      final next = (_currentPage + 1) % _partners.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_partners.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 140,
          child: PageView.builder(
            controller: _controller,
            itemCount: _partners.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _PartnerCard(
                partner: _partners[i],
                onCouponCopied: () =>
                    widget.onCouponCopied?.call(_partners[i]),
              ),
            ),
          ),
        ),
        if (_partners.length > 1) ...[
          const SizedBox(height: 10),
          _PageDots(count: _partners.length, current: _currentPage),
        ],
      ],
    );
  }
}

class _PartnerCard extends StatefulWidget {
  const _PartnerCard({required this.partner, this.onCouponCopied});
  final AffiliatePartner partner;
  final VoidCallback? onCouponCopied;

  @override
  State<_PartnerCard> createState() => _PartnerCardState();
}

class _PartnerCardState extends State<_PartnerCard> {
  bool _copied = false;

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: widget.partner.couponCode));
    widget.onCouponCopied?.call();
    setState(() => _copied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.partner.name} coupon copied!'),
        backgroundColor: AppUIConstants.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppUIConstants.radiusSm),
        ),
      ),
    );
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _visit() async {
    final uri = Uri.parse(widget.partner.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.partner;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppUIConstants.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        border: Border.all(
          color: AppUIConstants.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: verified + name
          Row(
            children: [
              Icon(
                Icons.verified_rounded,
                size: 18,
                color: AppUIConstants.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  p.name,
                  style: AppUIConstants.headingSm.copyWith(fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${p.tagline} — Get extra discount on courses',
            style: AppUIConstants.bodySm,
          ),
          const Spacer(),

          // Coupon row + visit button
          Row(
            children: [
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppUIConstants.surface,
                    borderRadius:
                        BorderRadius.circular(AppUIConstants.radiusSm),
                    border: Border.all(
                      color: AppUIConstants.primary.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          p.couponCode,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppUIConstants.primary,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _copyCode,
                        child: Icon(
                          _copied
                              ? Icons.check_rounded
                              : Icons.copy_rounded,
                          size: 18,
                          color: _copied
                              ? AppUIConstants.success
                              : AppUIConstants.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _visit,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppUIConstants.primary,
                    borderRadius:
                        BorderRadius.circular(AppUIConstants.radiusSm),
                  ),
                  child: const Text(
                    'Visit',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.current});
  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active
                ? AppUIConstants.primary
                : AppUIConstants.primary.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
