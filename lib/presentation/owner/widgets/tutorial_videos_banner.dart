import 'dart:convert';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../core/app_ui_constants.dart';

/// Always-visible tutorial-video carousel for the owner dashboard.
///
/// Videos are resolved in order:
///   1. Remote Config key [AppConstants.tutorialVideosConfigKey] (JSON array)
///   2. Single fallback [AppConstants.defaultTutorialVideo]
class TutorialVideosBanner extends StatefulWidget {
  const TutorialVideosBanner({
    super.key,
    required this.remoteConfig,
  });

  final FirebaseRemoteConfig remoteConfig;

  @override
  State<TutorialVideosBanner> createState() => _TutorialVideosBannerState();
}

class _TutorialVideosBannerState extends State<TutorialVideosBanner> {
  late final List<TutorialVideo> _videos;
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _videos = _resolveVideos();
    _pageController = PageController(viewportFraction: 0.88);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<TutorialVideo> _resolveVideos() {
    try {
      final json = widget.remoteConfig.getString(
        AppConstants.tutorialVideosConfigKey,
      );
      if (json.isNotEmpty) {
        final decoded = jsonDecode(json);
        if (decoded is List && decoded.isNotEmpty) {
          return decoded
              .map((e) => TutorialVideo.fromJson(e as Map<String, dynamic>))
              .where((v) => v.url.isNotEmpty)
              .toList();
        }
      }
    } catch (_) {
      // Fall through to default
    }
    return [AppConstants.defaultTutorialVideo];
  }

  Future<void> _openVideo(TutorialVideo video) async {
    final uri = Uri.tryParse(video.url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_videos.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(),
        const SizedBox(height: AppUIConstants.spacingMd),
        SizedBox(
          height: 140,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _videos.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, index) => _VideoCard(
              video: _videos[index],
              onTap: () => _openVideo(_videos[index]),
            ),
          ),
        ),
        if (_videos.length > 1) ...[
          const SizedBox(height: AppUIConstants.spacingSm),
          _buildPageIndicator(),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(
          Icons.play_circle_outline_rounded,
          size: 18,
          color: AppUIConstants.textSecondary,
        ),
        const SizedBox(width: 6),
        Text(
          'Video Tutorials',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppUIConstants.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_videos.length, (i) {
        final isActive = i == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 20 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive ? AppUIConstants.primary : AppUIConstants.border,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

class _VideoCard extends StatelessWidget {
  const _VideoCard({required this.video, required this.onTap});

  final TutorialVideo video;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final thumbnail = video.thumbnailUrl;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: AppUIConstants.surface,
        borderRadius: BorderRadius.circular(AppUIConstants.radiusMd),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Row(
            children: [
              _buildThumbnail(thumbnail),
              Expanded(child: _buildInfo()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(String? thumbnail) {
    return Container(
      width: 150,
      decoration: BoxDecoration(
        color: AppUIConstants.primary.withValues(alpha: 0.08),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (thumbnail != null)
            Image.network(
              thumbnail,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _placeholderIcon(),
            )
          else
            _placeholderIcon(),
          Center(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderIcon() {
    return Center(
      child: Icon(
        Icons.ondemand_video_rounded,
        size: 40,
        color: AppUIConstants.textTertiary,
      ),
    );
  }

  Widget _buildInfo() {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.smart_display_rounded,
                    size: 12, color: Colors.red.shade600),
                const SizedBox(width: 4),
                Text(
                  'YouTube',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            video.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppUIConstants.textPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Watch now',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppUIConstants.accent,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_forward_rounded,
                size: 14,
                color: AppUIConstants.accent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
