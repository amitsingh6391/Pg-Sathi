import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../../core/app_ui_constants.dart';

/// Fullscreen image viewer with zoom and swipe navigation.
class FullScreenImageViewer extends StatefulWidget {
  const FullScreenImageViewer({
    super.key,
    required this.images,
    required this.initialIndex,
    this.heroTagPrefix,
  });

  final List<String> images;
  final int initialIndex;
  final String? heroTagPrefix;

  /// Opens the fullscreen viewer as a modal route.
  static Future<void> open(
    BuildContext context, {
    required List<String> images,
    required int initialIndex,
    String? heroTagPrefix,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: AppUIConstants.background,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FullScreenImageViewer(
            images: images,
            initialIndex: initialIndex,
            heroTagPrefix: heroTagPrefix,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);

    // Hide status bar for immersive experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _pageController.dispose();
    // Restore status bar
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      _isZoomed = false;
    });
  }

  void _goTo(int index) {
    HapticFeedback.selectionClick();
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUIConstants.background,
      body: Stack(
        children: [
          // Image viewer with swipe
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              physics: _isZoomed
                  ? const NeverScrollableScrollPhysics()
                  : const BouncingScrollPhysics(),
              itemCount: widget.images.length,
              itemBuilder: (context, index) {
                return _ZoomableImage(
                  imageUrl: widget.images[index],
                  // Tag must match the Hero tag used in the source widget.
                  // We use prefix + URL (not index) so the tag is unique
                  // even when a carousel recycles the same index slot.
                  heroTag: widget.heroTagPrefix != null
                      ? '${widget.heroTagPrefix}_${widget.images[index]}'
                      : null,
                  onZoomChanged: (isZoomed) {
                    setState(() => _isZoomed = isZoomed);
                  },
                );
              },
            ),
          ),

          // Top bar with close button
          _buildTopBar(context),

          // Bottom filmstrip
          if (widget.images.length > 1) _buildFilmstrip(),
        ],
      ),
    );
  }

  Widget _glassButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.14),
        shape: const CircleBorder(side: BorderSide(color: Colors.white24)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          right: 16,
          bottom: 24,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppUIConstants.background.withValues(alpha: 0.85),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          children: [
            _glassButton(
              icon: Icons.close_rounded,
              tooltip: 'Close',
              onTap: () => Navigator.of(context).pop(),
            ),
            const Spacer(),
            if (widget.images.length > 1)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  border: Border.all(color: Colors.white24),
                  borderRadius: BorderRadius.circular(
                    AppUIConstants.radiusFull,
                  ),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.images.length}',
                    key: ValueKey(_currentIndex),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilmstrip() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: 28,
          bottom: MediaQuery.of(context).padding.bottom + 16,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              AppUIConstants.background.withValues(alpha: 0.9),
              Colors.transparent,
            ],
          ),
        ),
        child: SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: widget.images.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final selected = index == _currentIndex;
              return GestureDetector(
                onTap: () => _goTo(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      AppUIConstants.radiusSm,
                    ),
                    border: Border.all(
                      color: selected
                          ? AppUIConstants.primaryLight
                          : Colors.white.withValues(alpha: 0.2),
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Opacity(
                    opacity: selected ? 1 : 0.6,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        AppUIConstants.radiusSm - 2,
                      ),
                      child: Image.network(
                        widget.images[index],
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const ColoredBox(
                          color: AppUIConstants.surfaceMuted,
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            size: 18,
                            color: AppUIConstants.textTertiary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Zoomable image widget using InteractiveViewer.
class _ZoomableImage extends StatefulWidget {
  const _ZoomableImage({
    required this.imageUrl,
    this.heroTag,
    this.onZoomChanged,
  });

  final String imageUrl;
  final String? heroTag;
  final ValueChanged<bool>? onZoomChanged;

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage>
    with SingleTickerProviderStateMixin {
  final TransformationController _transformationController =
      TransformationController();
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;

  static const double _minScale = 1.0;
  static const double _maxScale = 4.0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onDoubleTap(TapDownDetails details) {
    final position = details.localPosition;
    final currentScale = _transformationController.value.getMaxScaleOnAxis();

    Matrix4 endMatrix;
    if (currentScale > 1.0) {
      // Zoom out to original
      endMatrix = Matrix4.identity();
    } else {
      // Zoom in to 2.5x centered on tap position
      endMatrix = Matrix4.identity()
        // ignore: deprecated_member_use
        ..translate(-position.dx * 1.5, -position.dy * 1.5)
        // ignore: deprecated_member_use
        ..scale(2.5, 2.5, 1.0);
    }

    _animation =
        Matrix4Tween(
          begin: _transformationController.value,
          end: endMatrix,
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward(from: 0).then((_) {
      _transformationController.value = endMatrix;
    });

    _animationController.addListener(() {
      if (_animation != null) {
        _transformationController.value = _animation!.value;
      }
    });
  }

  void _onInteractionUpdate(ScaleUpdateDetails details) {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    widget.onZoomChanged?.call(scale > 1.1);
  }

  void _onInteractionEnd(ScaleEndDetails details) {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    widget.onZoomChanged?.call(scale > 1.1);
  }

  @override
  Widget build(BuildContext context) {
    Widget imageWidget = Image.network(
      widget.imageUrl,
      fit: BoxFit.contain,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                : null,
            color: AppUIConstants.primaryLight,
            strokeWidth: 2,
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppUIConstants.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppUIConstants.border),
                ),
                child: const Icon(
                  Icons.broken_image_rounded,
                  color: AppUIConstants.textTertiary,
                  size: 36,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Failed to load image',
                style: TextStyle(color: AppUIConstants.textSecondary),
              ),
            ],
          ),
        );
      },
    );

    if (widget.heroTag != null) {
      imageWidget = Hero(tag: widget.heroTag!, child: imageWidget);
    }

    return GestureDetector(
      onDoubleTapDown: _onDoubleTap,
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: _minScale,
        maxScale: _maxScale,
        onInteractionUpdate: _onInteractionUpdate,
        onInteractionEnd: _onInteractionEnd,
        child: Center(child: imageWidget),
      ),
    );
  }
}
