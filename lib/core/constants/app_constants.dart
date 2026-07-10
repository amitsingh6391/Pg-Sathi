/// App-level constants shared across all layers.
abstract class AppConstants {
  /// Google Play Store listing URL.
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=in.pgsathi.app';

  /// Apple App Store listing URL.
  static const String appStoreUrl =
      'https://apps.apple.com/in/app/pg-sathi/id6757129948';

  /// Remote Config key for the tutorial videos JSON array.
  static const String tutorialVideosConfigKey = 'tutorial_videos';

  /// Single fallback video shown when Remote Config has no list.
  static const TutorialVideo defaultTutorialVideo = TutorialVideo(
    title: 'Getting Started',
    url: 'https://youtu.be/_En8dSt3cgE?si=1dyzS890XlZHSG2P',
  );

  // AFFILIATE PARTNERS

  static const List<AffiliatePartner> affiliatePartners = [
    AffiliatePartner(
      name: 'Adda247',
      couponCode: 'REF_XZGB2776',
      url: 'https://www.adda247.com',
      tagline: 'SSC, Banking & Govt Exam Prep',
    ),
    AffiliatePartner(
      name: 'Physics Wallah',
      couponCode: '9548IFHZ',
      url: 'https://www.pw.live',
      tagline: 'IIT-JEE, NEET & Foundation',
    ),
  ];
}

/// Immutable affiliate partner configuration.
class AffiliatePartner {
  const AffiliatePartner({
    required this.name,
    required this.couponCode,
    required this.url,
    required this.tagline,
  });

  final String name;
  final String couponCode;
  final String url;
  final String tagline;
}

/// Immutable tutorial video entry (title + YouTube URL).
class TutorialVideo {
  const TutorialVideo({required this.title, required this.url});

  final String title;
  final String url;

  factory TutorialVideo.fromJson(Map<String, dynamic> json) {
    return TutorialVideo(
      title: json['title'] as String? ?? '',
      url: json['url'] as String? ?? '',
    );
  }

  /// Extracts the YouTube video ID from various URL formats.
  String? get videoId {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    if (uri.host.contains('youtu.be')) return uri.pathSegments.firstOrNull;
    if (uri.host.contains('youtube.com')) return uri.queryParameters['v'];
    return null;
  }

  String? get thumbnailUrl {
    final id = videoId;
    if (id == null) return null;
    return 'https://img.youtube.com/vi/$id/hqdefault.jpg';
  }
}
