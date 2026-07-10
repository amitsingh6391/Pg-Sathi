import 'package:equatable/equatable.dart';

/// Represents a current affairs news item for student exam preparation.
class CurrentAffair extends Equatable {
  const CurrentAffair({
    required this.id,
    required this.title,
    required this.summary,
    required this.content,
    required this.category,
    required this.createdAt,
    this.source,
    this.imageUrl,
    this.publishedAt,
    this.createdBy,
    this.isBookmarked = false,
    this.viewCount = 0,
    this.likeCount = 0,
    this.isLiked = false,
  });

  final String id;
  final String title;

  /// Short 1-2 line summary shown in list view.
  final String summary;

  /// Full article content in markdown-friendly plain text.
  final String content;

  final CurrentAffairsCategory category;
  final DateTime createdAt;

  /// Source attribution (e.g., "The Hindu", "PIB").
  final String? source;

  /// Optional cover image URL.
  final String? imageUrl;

  /// When this item was published to students.
  final DateTime? publishedAt;

  /// Admin/owner who created this item.
  final String? createdBy;

  /// Whether the current student has bookmarked this.
  final bool isBookmarked;

  /// Server-side atomic counter incremented on each unique view.
  final int viewCount;

  /// Server-side atomic counter incremented/decremented on like toggle.
  final int likeCount;

  /// Whether the current student has liked this article.
  final bool isLiked;

  bool get isPublished => publishedAt != null;

  String get categoryLabel => category.label;

  CurrentAffair copyWith({
    String? id,
    String? title,
    String? summary,
    String? content,
    CurrentAffairsCategory? category,
    DateTime? createdAt,
    String? source,
    String? imageUrl,
    DateTime? publishedAt,
    String? createdBy,
    bool? isBookmarked,
    int? viewCount,
    int? likeCount,
    bool? isLiked,
  }) {
    return CurrentAffair(
      id: id ?? this.id,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      content: content ?? this.content,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      source: source ?? this.source,
      imageUrl: imageUrl ?? this.imageUrl,
      publishedAt: publishedAt ?? this.publishedAt,
      createdBy: createdBy ?? this.createdBy,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      viewCount: viewCount ?? this.viewCount,
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        summary,
        content,
        category,
        createdAt,
        source,
        imageUrl,
        publishedAt,
        createdBy,
        isBookmarked,
        viewCount,
        likeCount,
        isLiked,
      ];
}

/// Categories for current affairs, aligned with competitive exam syllabi.
enum CurrentAffairsCategory {
  national('National'),
  international('International'),
  economy('Economy'),
  science('Science & Tech'),
  environment('Environment'),
  polity('Polity & Governance'),
  sports('Sports'),
  defense('Defence'),
  other('General');

  const CurrentAffairsCategory(this.label);
  final String label;
}
